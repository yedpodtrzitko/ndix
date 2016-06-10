#!/bin/bash
cat "../server.vars" "server.password" > "server.cfg"
rsync --rsync-path="sudo rsync" "./server.cfg" phoenix:/home/steam/nd/nucleardawn/cfg/
rsync --rsync-path="sudo rsync" "./motd.txt" phoenix:/home/steam/nd/nucleardawn/
