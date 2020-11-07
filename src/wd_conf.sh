#!/bin/bash
set -x

. /usr/local/bin/lib.sh

. /usr/local/bin/init.sh

function watchLsyncConf {
  set -x
  if [ ! -z "$(findTaskOnHostOfService $serviceToSync)" ] ; then
    master=1
  else
    master=0
  fi
  if [ $master -eq 1 ] ; then
    if [ -e /var/run/lsyncd.pid ] ; then
      if ps -e | grep -q " $(cat /var/run/lsyncd.pid)" ; then
        return
      fi
    fi
    echo "This node is a master now"
    echo "Creation of the lsyncd configuration"
    mkdir -p $(dirname $lsyncdCfgFile)
    createLsyncConf "$lsyncdCfgFile" "$nodeName" "$mountpointsToSync"
    stdbuf -oL /usr/bin/lsyncd  -nodaemon -delay 5 $lsyncdCfgFile 2>&1 | sed -u -e 's/^/lsyncd: /' > /dev/null 2>&1 &
    lsyncdPid=$!
    echo $lsyncdPid > /var/run/lsyncd.pid
    echo "Started lsyncd with pid $lsyncdPid"
  else
    if [ ! -e /var/run/lsyncd.pid ] ; then
      return
    fi
    echo "This node is not a master yet"
    kill $(cat /var/run/lsyncd.pid)
    rm /var/run/lsyncd.pid
  fi
}

function watchNodesConf {
  nodesString=$(findServiceTasks $service) 
  createCsyncConfig "$csync2CfgDir" "$nodesString" "$keyFile" "$mountpointsToSync"
}

export -f watchLsyncConf
export -f watchNodesConf
export -f createLsyncConf
export -f findTaskOnHostOfService
export -f findServiceTasks
export -f createCsyncConfig
export service
export stack
export csync2CfgDir
export nodesString
export keyFile
export serviceToSync
export lsyncdCfgFile
export nodeName
export mountpointsToSync


date
curl -s -N --unix-socket /var/run/docker.sock http://localhost/events | grep --line-buffer '\("status":"start".\+"Type":"container"\)\|\("status":"exec_die".\+"Type":"container"\)\|\("Type":"service"\)\|\("Type":"node"\)' | grep --line-buffer $stack | xargs -L 1 bash -c 'set -x ; date; sleep 60 ; watchLsyncConf ; watchNodesConf' > /dev/stdout 2>&1 &

watchLsyncConf

set +x

while true; do
  sleep 2
done

