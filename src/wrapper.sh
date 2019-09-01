#!/bin/bash
set -x

. /usr/local/bin/lib.sh
. /usr/local/bin/input.sh

. /usr/local/bin/init.sh


pids=$(cat /var/run/*.pid)
sleep 5

oldNodesString=$nodesString

while true ; do
  
  sleep 2

  for pid in $pids ; do
    if ! ps -e | grep -q " $pid " ; then
      echo "PID $pid not found, exit"
      exit 2
    fi
  done

  nodesString=$(findNodeString $service) 
  if [ "$oldNodesString" != "$nodesString" ] ; then
    createCsyncConfig "$csync2CfgDir" "$nodesString" "$keyFile" "$dirsString"
    oldNodesString=$nodesString
  fi

done

