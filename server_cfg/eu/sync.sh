#!/bin/bash
cat "../server.vars" "server.password" > "server.cfg"
rsync --rsync-path="sudo rsync" "./server.cfg" ndix:/home/steam/nd/nucleardawn/cfg/
rsync --rsync-path="sudo rsync" "./motd.txt" ndix:/home/steam/nd/nucleardawn/
