#!/bin/bash
set -x

. /usr/local/bin/lib.sh
. /usr/local/bin/input.sh


/usr/local/bin/wd_conf.sh > /dev/stdout 2>&1 &

sleep 5

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
 
done

