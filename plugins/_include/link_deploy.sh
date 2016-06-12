#!/bin/bash
SRC=`pwd`
cd ../../deploy_server/addons/sourcemod/scripting/include/
ln -s $SRC/*.inc .
