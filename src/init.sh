#!/bin/bash


######
# MAIN
serviceSync_label='async.service'
volumeSync_label='async.volumes'

###
# Find the service that I have to support
# and check the existance
service="$(findMyService)"
[ -z "$service" ] && echo "My service not found" && exit 2
serviceToSync="$(findValueByLabel $service $serviceSync_label)"
[ -z "$serviceToSync" ] && echo "Service to sync not found" && exit 2

stack=$(findMyStack)
[ -z "$stack" ] && echo "My stack not found" && exit 2
servicesInStack="$(findAllServicesOfStack $stack)"
[ -z "$servicesInStack" ] && echo "Services not found" && exit 2
ok=0
for serv in $(echo $servicesInStack | tr ',' ' ') ; do
  if [ $serv == "${stack}_$serviceToSync" ] ; then
    ok=1
  fi
done
if [ $ok -eq 0 ] ; then
  echo "$serviceToSync not found" && exit 2
fi
serviceToSync="${stack}_$serviceToSync"

# Find volumes to sync
# and consequent mountpoints to sync
volumesToSync=$(findValueByLabel $serviceToSync $volumeSync_label)
[ -z "$volumesToSync" ] && echo "Volumes to sync not found" && exit 2
mountpoints="$(findMountpoints $service)"
[ -z "$mountpoints" ] && echo "Mountpoints not found" && exit 2
mountpointsToSync=""
for mnt in $(echo $mountpoints | tr ',' ' ') ; do 
  for vol in $(echo $volumesToSync | tr ',' ' ') ; do
    if [ ${mnt%:*} == "${stack}_${vol}" ] ; then
      mountpointsToSync="$mountpointsToSync${mnt#*:},"
    fi
  done
done

[ -z "$mountpointsToSync" ] && echo "Mountpoints not found2" && exit 2

# Find if this node will be a master
master=0
tasksService="$(findTaskOnHostOfService $serviceToSync)"
if [ ! -z "$tasksService" ] ; then
  echo "This node is a master"
  master=1
fi

###
# create csync2 certificate
if [ ! -e /etc/csync2_ssl_cert.pem ] ; then
    createCertificate
    echo "Wrote \"/etc/csync2_ssl_cert.pem\""
fi
###
# write csync2 key
echo "$key" > $keyFile
echo "Wrote \"$keyFile\""

###
# create csync2 cfg
#nodesString=$(findRunningNodes $service)
nodesString=$(findServiceTasks $service)
nodeName=$(findMyTaskName)
createCsyncConfig "$csync2CfgDir" "$nodesString" "$keyFile" "$mountpointsToSync"

if [ $master -eq 1 ] ; then
# create lsyncd cfg
    mkdir -p $(dirname $lsyncdCfgFile)
    createLsyncConf "$lsyncdCfgFile" "$nodeName" "$mountpointsToSync"
fi


## prepare dirs to sync if they don't exists
#for _dir in $(echo $mountpointsToSync | tr ',' '\n') ; do
#  mkdir -p $_dir
#done

###
# Run csync2

confName=$(echo $nodeName | tr -d '._-')
stdbuf -oL csync2 -ii -v -N $nodeName -C $confName | sed -u -e 's/^/csync2: /' > /dev/stdout 2>&1 &
csync2Pid=$!
echo $csync2Pid > /var/run/csync2.pid

echo "Started csync2 with pid $csync2Pid"

###
# run lsyncd

if [ $master -eq 1 ] ; then
    stdbuf -oL /usr/bin/lsyncd  -nodaemon -delay 5 $lsyncdCfgFile 2>&1 | sed -u -e 's/^/lsyncd: /' > /dev/stdout 2>&1 &
    lsyncdPid=$!
    echo $lsyncdPid > /var/run/lsyncd.pid
    echo "Started lsyncd with pid $lsyncdPid"
fi


