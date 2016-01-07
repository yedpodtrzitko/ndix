#!/bin/bash
cat "../server.vars" "server.password" > "server.cfg"
rsync  --rsync-path="sudo rsync" "./server.cfg" nd_aus:/home/steam/nd/nucleardawn/cfg/
rsync  --rsync-path="sudo rsync" "./motd.txt" nd_aus:/home/steam/nd/nucleardawn/
