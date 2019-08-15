#!/bin/bash


# input
# (k) Chiave: stringa base64 ( 8BLJdGh1bD03CLNoAwOwVljJaBj7Qmc9O9q )
# (d) Directories: lista di directory to sync ( /opt/data/,/opt/data2 )
# (i) Reset id: elimina l'ID di Csync2
# (r) Reset DB: eleimina il DB di Csync2

set -x
key=$CSYNC2_KEY
dirsString=$CSYNC2_DIRS

while getopts "k:d:" opt; do
  case $opt in
		k)
			key=$(echo $OPTARG | tr -d '[[:space:]]')
			;;
		d)
			dirsString=$(echo $OPTARG | tr -d '[[:space:]]')
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

[ -z "$key" ] && echo "Key is missing, define with -k" && exit 1
[ -z "$dirsString" ] && echo "Dirs is missing, define with -d" && exit 1

#VOLUMES
# /etc
# /var/lib/csync2
# /opt/dataN

csync2CfgDir=/etc/
lsyncdCfgFile=/etc/lsyncd/lsyncd.conf.lua
keyFile=/etc/csync2.key

######
# MAIN

###
# Find the siblings
for _container in $(docker ps --format '{{printf "%s;%s" .ID .Labels}}' | tr -d ' ') ; do
    if [ "${_container%;*}" == $(hostname -s) ] ; then
        for _label in $(echo ${_container#*;} | tr ',' '\n') ; do
            if echo $_label | grep -q 'com.docker.swarm.service.name' ; then
                service=${_label#*=}
            fi
            if echo $_label | grep -q 'com.docker.swarm.task.name' ; then
                nodeName=${_label#*=}
            fi
        done
    fi
done
[ -z "$service" ] && echo "Container service not found" && exit 2
nodesString=$(docker service ps --no-trunc -f "desired-state=running" $service --format '{{printf "%s.%s"  .Name .ID }}')


###
# create certificate
if [ ! -e /etc/csync2_ssl_cert.pem ] ; then
        openssl genrsa -out /etc/csync2_ssl_key.pem 1024
        ls -l /etc/csync2_ssl_key.pem
        openssl req -batch -new -key /etc/csync2_ssl_key.pem -out /etc/csync2_ssl_cert.csr
        ls -l /etc/csync2_ssl_cert.csr
        openssl x509 -req -days 3600 -in /etc/csync2_ssl_cert.csr -signkey /etc/csync2_ssl_key.pem -out /etc/csync2_ssl_cert.pem
        ls -l /etc/csync2_ssl_cert.pem
        echo "Wrote \"/etc/csync2_ssl_cert.pem\""
fi

###
# create csync2 cfg
mkdir -p $csync2CfgDir
for __host in $nodesString ; do
        csync2CfgFile="$csync2CfgDir/csync2_$(echo ${__host} | tr -d '._-').cfg"
        echo -e "group mycluster \n{" > $csync2CfgFile
        for _host in $nodesString ; do
                if [  "$_host" != "$__host" ] ; then
                        # host slave
                        echo    "    host ($_host);"   >> $csync2CfgFile
                else
                        # host master
                        echo    "    host $_host;"   >> $csync2CfgFile
                fi
        done
        echo    "    key $keyFile;"  >> $csync2CfgFile
        for _dir in $(echo $dirsString | tr ',' '\n') ; do
                echo    "    include $_dir;" >> $csync2CfgFile
        done
        echo    "    exclude *~ .*;" >> $csync2CfgFile
        echo    "}"                  >> $csync2CfgFile

        echo "Wrote \"$csync2CfgFile\""
done

confName=$(echo $nodeName | tr -d '._-')
echo "configuration name: $confName"
mkdir -p $(dirname $lsyncdCfgFile)
# create lsyncd cfg
cat << EOF > $lsyncdCfgFile
settings {
        logident        = "lsyncd",
        logfacility     = "daemon",
        logfile         = "/dev/null",
        statusFile      = "/var/log/lsyncd_status.log",
        statusInterval  = 1
}
initSync = {
        delay = 1,
        maxProcesses = 1,
        exitcodes = {[1] = 'again'},
        action = function(inlet)
                local config = inlet.getConfig()
                local elist = inlet.getEvents(function(event)
                        return event.etype ~= "Init"
                end)
                local directory = string.sub(config.source, 1, -2)
                local paths = elist.getPaths(function(etype, path)
                        return "\t" .. config.syncid .. ":" .. directory .. path
                end)
                log("Normal", "Processing syncing list:\n", table.concat(paths, "\n"))
                spawn(elist, "/usr/sbin/csync2", "-x", "-C", config.syncid, "-N", "$nodeName")
        end,
        collect = function(agent, exitcode)
                local config = agent.config
                if not agent.isList and agent.etype == "Init" then
                        if exitcode == 0 then
                                log("Normal", "Startup of '", config.syncid, "' instance finished.")
                        elseif config.exitcodes and config.exitcodes[exitcode] == "again" then
                                log("Normal", "Retrying startup of '", config.syncid, "' instance. RC=" .. exitcode)
                                return "again"
                        else
                                log("Error", "Failure on startup of '", config.syncid, "' instance. RC=" .. exitcode)
                                terminate(-1)
                        end
                        return
                end
                local rc = config.exitcodes and config.exitcodes[exitcode]
                if rc == "die" then
                        return rc
                end
                if agent.isList then
                        if rc == "again" then
                                log("Normal", "Retrying events list on exitcode = ", exitcode)
                        else
                                log("Normal", "Finished events list = ", exitcode)
                        end
                else
                        if rc == "again" then
                                log("Normal", "Retrying ", agent.etype, " on ", agent.sourcePath, " = ", exitcode)
                        else
                                log("Normal", "Finished ", agent.etype, " on ", agent.sourcePath, " = ", exitcode)
                        end
                end
                return rc
        end,
        init = function(event)
                local inlet = event.inlet;
                local config = inlet.getConfig();
                log("Normal", "Recursive startup sync: ", config.syncid, ":", config.source)
                spawn(event, "/usr/sbin/csync2", "-C", config.syncid, "-xr", "-N", "$nodeName")
        end,
        prepare = function(config)
                if not config.syncid then
                        error("Missing 'syncid' parameter.", 4)
                end
                local c = "csync2_" .. config.syncid .. ".cfg"
                local f, err = io.open("/etc/" .. c, "r")
                if not f then
                        error("Invalid 'syncid' parameter: " .. err, 4)
                end
                f:close()
        end
}
local sources = {
$(for _dir in $(echo $dirsString | tr ',' '\n') ; do echo "        [\"$_dir\"] = \"$confName\","; done)
}
for key, value in pairs(sources) do
        sync {initSync, source=key, syncid=value}
end
EOF
for _dir in $(echo $dirsString | tr ',' '\n') ; do
  mkdir -p $_dir
done

echo "Wrote \"$lsyncdCfgFile\""

###
# write csync2 key
echo "$key" > $keyFile
echo "Wrote \"$keyFile\""


###
# Run csync2

stdbuf -oL csync2 -ii -v -N $nodeName -C $confName | sed -u -e 's/^/csync2: /' > /dev/stdout 2>&1 &
csync2Pid=$!
echo $csync2Pid > /var/run/csync2.pid

echo "Started csync2 with pid $csync2Pid"

###
# run lsyncd

stdbuf -oL /usr/bin/lsyncd  -nodaemon -delay 5 $lsyncdCfgFile 2>&1 | sed -u -e 's/^/lsyncd: /' > /dev/stdout 2>&1 &
lsyncdPid=$!
echo $lsyncdPid > /var/run/lsyncd.pid

echo "Started lsyncd with pid $lsyncdPid"

