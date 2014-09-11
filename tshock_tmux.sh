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
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

# Server variables
NAME=Test
PORT=12345
MAXPLAYERS=8
USERID=terraria
HOMEDIR=/home/terraria
TSHOCKDIR=/home/terraria/Test
WORLDDIR=/home/terraria/Worlds
WORLDFILE=Test.wld

# Configure proper mono runtime with sgen garbage collection
# sgen garbage collection is default 3.1.1 onward
# Use 'mono-sgen' with mono <=3.1.0
# Use 'mono' with mono >=3.1.1
MONODAEMON=$(which mono)
TMUXDAEMON=$(which tmux)

TERRARIA=${TSHOCKDIR}/TerrariaServer.exe
TMUXPID=${TSHOCKDIR}/tshock/${NAME}.pid
TMUXSOCKET=${HOMEDIR}/tmux.tshock
TSHOCKPID=${TSHOCKDIR}/tshock/tshock.pid
WORLD=${WORLDDIR}/${WORLDFILE}

# All arguments for TerrariaServer.exe
TERRARIAARGS="-port ${PORT} -world ${WORLD} -maxplayers ${MAXPLAYERS} -killinactivesocket"

# Warning time for connected users before exit
EXIT_WARNING=5
# Command sent to server to exit (exit|exit-nosave)
EXIT_COMMAND="exit"
# Wait X seconds for terraria to exit
EXIT_TIMEOUT=30

[ -f /lib/init/vars.sh ] && . /lib/init/vars.sh || exit 0
[ -f /lib/lsb/init-functions ] && . /lib/lsb/init-functions || exit 0

checkTMUXSOCKET() {
    ${TMUXDAEMON} -S ${TMUXSOCKET} has-session > /dev/null 2>&1
    return $?
}

checkPID() {
    PIDTOCHECK=$1
    if [ -e ${PIDTOCHECK} ] && kill -0 $(cat ${PIDTOCHECK} 2>/dev/null) > /dev/null 2>&1; then
        return 0
    else
        return 1
	fi
}

checkTMUXWINDOW() {
    checkTMUXSOCKET
    case "$?" in
        0 )
            WINDOWFOUND=$(${TMUXDAEMON} -S ${TMUXSOCKET} list-window | grep ${NAME})
            if [ -z "${WINDOWFOUND}" ]; then
                return 1
            else
                return 0
            fi
        ;;
        1 )
            return 1
        ;;
    esac
}

do_start() {
    # Return
    #   0 if daemon has been started
    #   1 if daemon was already running
    #   2 if daemon could not be started
    start-stop-daemon --start --quiet \
        --chdir ${TSHOCKDIR} \
        --pidfile ${TMUXPID} \
        --exec ${TMUXDAEMON} \
        --test > /dev/null \
        || return 1

    checkTMUXSOCKET
    case "$?" in
        0 ) # tmux session found, start new window
            start-stop-daemon --start --quiet \
                --chdir ${TSHOCKDIR} \
                --pidfile ${TMUXPID} \
                --chuid ${USERID} \
                --exec ${TMUXDAEMON} \
                -- -2 -S ${TMUXSOCKET} new-window -d -n ${NAME} "${MONODAEMON} ${TERRARIA} ${TERRARIAARGS}" \
                || return 2
        ;;
        1 ) # No tmux session found, start new session
            start-stop-daemon --start --quiet \
                --chdir ${TSHOCKDIR} \
                --pidfile ${TMUXPID} \
                --chuid ${USERID} \
                --exec ${TMUXDAEMON} \
                -- -2 -S ${TMUXSOCKET} new-session -d -n ${NAME} -s tShock "${MONODAEMON} ${TERRARIA} ${TERRARIAARGS}" \
                || return 2
        ;;
    esac

    # Create pidfile and set correct ownership
    echo $(pgrep -u ${USERID} -f "${TMUXDAEMON} -2 -S ${TMUXSOCKET}") > ${TMUXPID}
    chown ${USERID}:${USERID} ${TMUXPID}
    chown ${USERID}:${USERID} ${TMUXSOCKET}
    chmod 660 ${TMUXSOCKET} # owner and group can connect to tmux session
}

do_stop() {
    # Return
    #   0 if daemon has been stopped
    #   1 if daemon was already stopped
    #   2 if daemon could not be stopped
    RETVAL=2
    if ! checkTMUXSOCKET; then
        log_progress_msg "WARNING: tmux not running (tShock already stopped)"
        echo "WARNING: tmux not running (tShock already stopped)"
        RETVAL=1
    elif  ! checkPID ${TSHOCKPID}; then
        log_progress_msg "WARNING: tShock pidfile stale (tShock already stopped)"
        echo "WARNING: tShock pidfile stale (tShock already stopped)"
        RETVAL=1
    else
        echo "Please wait ${EXIT_WARNING} seconds to warn connected users..."
        # Use 'send-keys' to push commands to tShock console
        # Warn connected users server is shutting down
        ${TMUXDAEMON} -S ${TMUXSOCKET} send-keys -t tShock:${NAME} 'say Server shutting down in '${EXIT_WARNING}' seconds...' Enter
        sleep ${EXIT_WARNING}

        # Send exit command to server
        ${TMUXDAEMON} -S ${TMUXSOCKET} send-keys -t tShock:${NAME} 'exit' Enter
		
        # Wait for the process to end
        n=${EXIT_TIMEOUT}
        for (( i=0; i<n; i++ )); do
            if ! checkTMUXWINDOW; then
                rm -f ${TMUXPID}
                if ! checkTMUXSOCKET; then rm -f ${TMUXSOCKET}; fi
                RETVAL=0
                break
            fi
            sleep 1
        done
    fi
    return ${RETVAL}
}

do_status() {
    if ! checkTMUXSOCKET; then
        log_progress_msg "ERROR: (tmux not running)"
        echo "ERROR: (tmux not running)"
    elif ! checkTMUXWINDOW; then
        log_progress_msg "ERROR: (tmux window '${NAME}' not found)"
        echo "ERROR: (tmux window '${NAME}' not found)"
    fi
    status_of_proc -p ${TSHOCKPID} ${MONODAEMON} ${NAME} || return $?
}

do_connect() {
    # Return
    #   0 if connection successful
    #   1 if tmux was not running/window not found
    #   2 if connection was unsuccessful
    if ! checkTMUXSOCKET; then
        log_progress_msg "ERROR: Connect failed. (tmux not running)"
        echo "ERROR: Connect failed. (tmux not running)" && return 1
    elif ! checkTMUXWINDOW; then
        log_progress_msg "ERROR: Connect failed. (tmux window '${NAME}' not found)"
        echo "ERROR: Connect failed. (tmux window '${NAME}' not found)" && return 1	
    else
        # Select the correct tmux server window prior to connecting
        ${TMUXDAEMON} -S ${TMUXSOCKET} select-window -t tShock:${NAME}
        # Connect to the tShock tmux session
        ${TMUXDAEMON} -S ${TMUXSOCKET} attach || return 2
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
