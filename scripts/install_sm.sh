#!/bin/bash
pause "copy me into the directory 'nucleardawn'"
SM="sourcemod-1.6.3-linux.tar.gz"
MM="mmsource-1.10.4-linux.tar.gz"
TMP="_download"

mkdir $TMP

wget -P $TMP http://sourcemod.gameconnect.net/files/${SM}
wget -P $TMP http://sourcemod.gameconnect.net/files/${MM}

tar xzf  ./${TMP}/${SM}
tar xzf ./${TMP}/${MM}
