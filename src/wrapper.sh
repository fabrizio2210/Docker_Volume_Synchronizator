#!/bin/bash
set -x

. /usr/local/bin/lib.sh
. /usr/local/bin/input.sh

. /usr/local/bin/init.sh


sleep 5

oldNodesString=$nodesString
oldMaster=$master
set +x
while true ; do
  
  sleep 2

  pids=$(cat /var/run/*.pid)
  for pid in $pids ; do
    if ! ps -e | grep -q " $pid " ; then
      echo "PID $pid not found, exit"
      [ -z "$DEBUG" ] && exit 2
    fi
  done
 
  
  if [ ! -z "$(findTaskOnHostOfService $serviceToSync)" ] ; then
    master=1
  else
    master=0
  fi
  if [ $oldMaster != $master ] ; then
    if [ $master -eq 1 ] ; then
      echo "This node is a master now"
      echo "Creation of the lsyncd configuration"
      mkdir -p $(dirname $lsyncdCfgFile)
      createLsyncConf "$lsyncdCfgFile" "$nodeName" "$mountpointsToSync"
      stdbuf -oL /usr/bin/lsyncd  -nodaemon -delay 5 $lsyncdCfgFile 2>&1 | sed -u -e 's/^/lsyncd: /' > /dev/stdout 2>&1 &
      lsyncdPid=$!
      echo $lsyncdPid > /var/run/lsyncd.pid
      echo "Started lsyncd with pid $lsyncdPid"
    else
      echo "This node is not a master yet"
      kill $(cat /var/run/lsyncd.pid)
      rm /var/run/lsyncd.pid
    fi
    oldMaster=$master
  fi

  nodesString=$(findServiceTasks $service) 
  if [ "$oldNodesString" != "$nodesString" ] ; then
    createCsyncConfig "$csync2CfgDir" "$nodesString" "$keyFile" "$mountpointsToSync"
    oldNodesString=$nodesString
  fi

done

