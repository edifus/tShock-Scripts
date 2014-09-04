tShock-Scripts
==============

tShock Debian / Ubuntu init scripts

I created these scripts to host multiple tShock maps on my server.

I originally updated the script found here: [nooblet.org](http://www.nooblet.org/blog/2013/installing-tshock-terraria-server-on-debian-wheezy/).
I needed to be able to run multiple maps under the same user account so I adapted the script for that purpose.

After a while I wanted to not use tmux instead of screen. I find screen clunky and hard to use reliably when connecting to session from other users.

The screen version of the script will launch a new screen session which can be connected to as the terraria user or through this script.

The tmux version will launch a new tmux session called 'tShock' and the script will then open new windows in this session for each server.
Any user that belongs to the same group-id as the 'terraria' user can easily connect to the tmux socket.

```
/home/terraria/                 ${HOMEDIR}
├── Test/                       ${TSHOCKDIR}
│   ├── ServerLog.txt
│   ├── ServerPlugins
│   │   ├── HttpServer.dll
│   │   ├── Mono.Data.Sqlite.dll
│   │   ├── MySql.Data.dll
│   │   ├── MySql.Web.dll
│   │   ├── Newtonsoft.Json.dll
│   │   └── TShockAPI.dll
│   ├── sqlite3.dll
│   ├── Terraria/
│   │   └── Worlds/
│   ├── TerrariaServer.exe      ${TERRARIA}
│   └── tshock/
│       ├── authcode.txt
│       ├── config.json
│       ├── motd.txt
│       ├── rules.txt
│       ├── sscconfig.json
│       ├── tshock.pid          ${TSHOCKPID}
│       ├── Test.pid            ${TMUXPID} / ${SCREENPID}
│       └── whitelist.txt
├── Worlds/                     ${WORLDDIR}
│   ├── Test.wld                ${WORLDFILE}
│   └── Test.wld.bak
└── tmux.tshock                 ${TMUXSOCKET}
```

TODO: Additional instructions to setup user account and directory structure.
