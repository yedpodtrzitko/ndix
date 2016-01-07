#!/bin/bash
TARGET="../../deploy_server"
for ITEM in plugins scripting translations gamedata configs
do
    if [ -d "$ITEM" ]; then
        echo "copying ${ITEM}"
        cp -R ./${ITEM} ${TARGET}/addons/sourcemod/
        echo "cp -R ./${ITEM} ${TARGET}/addons/sourcemod/"
    fi
done

for ITEM in cfg models materials
do
    if [ -d "$ITEM" ]; then
        echo "copying ${ITEM}"
        cp -R ./${ITEM} ${TARGET}
    fi
done
