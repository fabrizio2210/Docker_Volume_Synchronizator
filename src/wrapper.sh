#!/bin/bash


/usr/local/bin/init.sh $@


pids=$(cat /var/run/*.pid)
sleep 5
while true ; do
  
  sleep 2

  for pid in $pids ; do
    if ! ps -e | grep -q " $pid " ; then
      echo "PID $pid not found, exit"
      exit 2
    fi
  done

done

