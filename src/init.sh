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


###
# Run csync2

confName=$(echo $nodeName | tr -d '._-' | tr [A-Z] [a-z])
stdbuf -oL csync2 -ii -v -N $nodeName -C $confName 2>&1 | sed -u -e 's/^/csync2: /' > /dev/null 2>&1 &
csync2Pid=$!
echo $csync2Pid > /var/run/csync2.pid

echo "Started csync2 with pid $csync2Pid"

