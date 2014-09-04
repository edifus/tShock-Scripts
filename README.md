tShock-Scripts
==============

tShock Debian / Ubuntu init scripts

I created these scripts to host multiple tShock maps on my server
I originally updated the script found here: http://www.nooblet.org/blog/2013/installing-tshock-terraria-server-on-debian-wheezy/
I needed to be able to run multiple maps under the same user account so I adapted the script for that purpose.

The screen version of the script will launch a new screen session which can be connected to as the terraria user or through this script.

After awhile I wanted to not use screen. I find it clunky and hard to use reliably when connecting to session from other users.
I updated the script to use tmux instead. The tmux version will launch a new tmux session called 'tShock' and the script will then open new windows in this session for each server.
Any user that belongs to the same group-id as the 'terraria' user can easily connect to the tmux socket.

TODO: Additional instructions to setup user account and directory structure.
