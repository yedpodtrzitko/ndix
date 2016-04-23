#!/bin/bash
SRC=`pwd`
cd ~/nd/nucleardawn/addons/sourcemod/scripting
ln -s $SRC/scripting/*.sp .
ln -s $SRC/plugins/*.smx .
ln -s $SRC/scripting/include/*.inc ./include/
ln -s $SRC/translations/*.txt ../translations/
cd ~/nd/nucleardawn/addons/sourcemod/plugins
ln -s ../scripting/*.smx .
