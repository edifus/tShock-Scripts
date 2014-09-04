#!/bin/bash

### BEGIN INIT INFO
# Provides:		tshock_test
# Required-Start:	$local_fs $remote_fs $network
# Required-Stop:	$local_fs $remote_fs $network
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# X-Interactive:	true
# Short-Description:	Test tShock Server
### END INIT INFO

DESC="tShock Terraria Server:"
PATH=/sbin:/bin:/usr/sbin:/usr/bin

# Server variables
NAME=Test
PORT=12345
MAXPLAYERS=8
USERID=terraria
TSHOCKDIR=/home/terraria/Test
WORLDDIR=/home/terraria/Worlds
WORLDFILE=Test.wld

# Configure proper mono runtime with sgen garbage collection
# sgen garbage collection is default 3.1.1 onward
# Use 'mono-sgen' with mono <3.1.1
# Use 'mono' with mono >3.1.0
MONODAEMON=$(which mono)
SCREENDAEMON=$(which screen)

TERRARIA=${TSHOCKDIR}/TerrariaServer.exe
SCREENPID=${TSHOCKDIR}/tshock/${NAME}.pid
TSHOCKPID=${TSHOCKDIR}/tshock/tshock.pid
WORLD=${WORLDDIR}/${WORLDFILE}
SERVERSCREEN=/var/run/screen/S-${USERID}/*.${NAME}

# All arguments for TerrariaServer.exe
TERRARIAARGS="-port ${PORT} -world ${WORLD} -maxplayers ${MAXPLAYERS} -killinactivesocket"

# All screen daemon arguments for start-stop-daemon
SCREENDAEMONARGS="-dmS ${NAME} ${MONODAEMON} ${TERRARIA} ${TERRARIAARGS}"

# Warning time for connected users before exit
EXIT_WARNING=5
# Command sent to server to exit (exit|exit-nosave)
EXIT_COMMAND="exit"
# Wait X seconds for terraria to exit
EXIT_TIMEOUT=30

[ -f /lib/init/vars.sh ] && . /lib/init/vars.sh || exit 0
[ -f /lib/lsb/init-functions ] && . /lib/lsb/init-functions || exit 0

# Exit if screen cant be found
[ -x ${SCREENDAEMON} ] || exit 0
# Exit if mono cant be found
[ -x ${MONODAEMON} ] || exit 0
# Exit if TerrariaServer.exe cant be found
[ -r ${TERRARIA} ] || exit 0
# Exit if tShock folder cant be found
[ -d ${TSHOCKDIR} ] || exit 0

checkSERVERSCREEN() {
	if [ -e ${SERVERSCREEN} ]; then
		return 0
	else
		return 1
	fi
}

checkPID() {
	PIDTOCHECK=$1
	if [ -e ${PIDTOCHECK} ] && kill -0 $(cat ${PIDTOCHECK} 2>/dev/null) > /dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

do_start() {
	# Return
	#   0 if daemon has been started
	#   1 if daemon was already running
	#   2 if daemon could not be started
	start-stop-daemon --start --quiet \
		--chdir ${TSHOCKDIR} \
		--pidfile ${SCREENPID} \
		--chuid ${USERID} \
		--exec ${SCREENDAEMON} \
		--test > /dev/null \
		|| return 1
	start-stop-daemon --start --quiet \
		--chdir ${TSHOCKDIR} \
		--pidfile ${SCREENPID} \
		--chuid ${USERID} \
		--exec ${SCREENDAEMON} \
		-- ${SCREENDAEMONARGS} \
		|| return 2
	# Create pidfile and set correct ownership
	echo $(pgrep -f "/usr/bin/SCREEN -dmS ${NAME}") > ${SCREENPID}
	chown ${USERID}:${USERID} ${SCREENPID}
}

do_stop() {
	# Return
	#   0 if daemon has been stopped
	#   1 if daemon was already stopped
	#   2 if daemon could not be stopped
	RETVAL=2
	if ! checkSERVERSCREEN; then
		log_progress_msg "${NAME}: screen not running"
		echo "${NAME}: screen not running"
		RETVAL=1
	elif  ! checkPID ${SCREENPID}; then
		log_progress_msg "${NAME}: screen pidfile stale"
		echo "${NAME}: screen pidfile stale"
		RETVAL=1
	elif  ! checkPID ${TSHOCKPID}; then
		log_progress_msg "${NAME}: tShock pidfile stale"
		echo "${NAME}: tShock pidfile stale"
		RETVAL=1
	else
		echo "Please wait ${EXIT_WARNING} seconds to warn connected users.."
		# Use screen to "stuff" text to tShock
		# Warn connected users server is shutting down
		su "${USERID}" -c 'screen -dr '${NAME}' -X stuff "say Server shutting down in '${EXIT_WARNING}' seconds...$(printf \\r)"'
		sleep ${EXIT_WARNING}
		# Send exit command to server
		su "${USERID}" -c 'screen -dr '${NAME}' -X stuff "'${EXIT_COMMAND}'$(printf \\r)"'
		# Wait for the process to end
		n=${EXIT_TIMEOUT}
		for (( i=0; i<n; i++ )); do
			if ! checkSERVERSCREEN; then
				RETVAL=0
				rm -f ${SCREENPID}
				break
			fi
			sleep 1
		done
	fi
	return ${RETVAL}
}

do_status() {
	if ! checkSERVERSCREEN; then
		log_progress_msg "${NAME}: screen not running"
		echo "${NAME}: screen not running"
	elif  ! checkPID ${SCREENPID}; then
		log_progress_msg "${NAME}: screen pidfile stale"
		echo "${NAME}: screen pidfile stale"
	fi
	status_of_proc -p ${TSHOCKPID} ${MONODAEMON} ${NAME} || return $?
}

do_connect() {
	# Return
	#   0 if connection successful
	#   1 if screen was not running
	#   2 if connection was unsuccessful
	if checkSERVERSCREEN; then
		su "${USERID}" -c "script -qc \"screen -dr ${NAME}\" /dev/null" || return 2
	else
		log_progress_msg "${NAME}: Connect failed. (screen not running)"
		echo "${NAME}: Connect failed. (screen not running)" && return 1
	fi
}

case "$1" in
	start )
		log_daemon_msg "Starting ${DESC}" "${NAME}"
		do_start
		case "$?" in
			0 | 1 ) log_end_msg 0 ;; # Started successfully or already started
			* ) log_end_msg 2 ;; # Failed to start
		esac
	;;

	stop )
		log_daemon_msg "Stopping ${DESC}" "${NAME}"
		do_stop
		case "$?" in
			0 | 1 ) log_end_msg 0 ;; # Stopped successfully or already stopped
			* ) log_end_msg 2 ;; # Failed to stop
		esac
	;;

	restart )
		log_daemon_msg "Restarting ${DESC}" "${NAME}"
		do_stop
		case "$?" in
			0 | 1 ) # Stopped successfully or already stopped
				do_start
				case "$?" in
					0 | 1 ) log_end_msg 0 ;; # Started successfully or already started
					* ) log_end_msg 2 ;; # Failed to restart
				esac
			;;
			* ) log_end_msg 2 ;; # Failed to stop
		esac
	;;

	status )
		do_status && exit 0 || exit $?
	;;

	connect )
		do_connect && exit 0 || exit $?
	;;

	* )
		echo "Usage: $0 {start|stop|restart|status|connect}" 2>&1
		exit 3
	;;
esac
