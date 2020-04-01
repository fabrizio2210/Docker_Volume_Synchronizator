
#VOLUMES
# /etc
# /var/lib/csync2
# /opt/dataN

# Constants
csync2CfgDir=/etc/
lsyncdCfgFile=/etc/lsyncd/lsyncd.conf.lua
keyFile=/etc/csync2.key

# r -> my_stack
function findMyStack {
    for _container in $(docker ps --format '{{printf "%s;%s" .ID .Labels}}' | tr -d ' ') ; do
        if [ "${_container%;*}" == $(hostname -s) ] ; then
            for _label in $(echo ${_container#*;} | tr ',' '\n') ; do
                if echo $_label | grep -q 'com.docker.stack.namespace' ; then
                    local _stack=${_label#*=}
										echo $_stack
                    return
                fi
            done
        fi
    done
}

# r -> my_stack_async
function findMyService {
    for _container in $(docker ps --format '{{printf "%s;%s" .ID .Labels}}' | tr -d ' ') ; do
        if [ "${_container%;*}" == $(hostname -s) ] ; then
            for _label in $(echo ${_container#*;} | tr ',' '\n') ; do
                if echo $_label | grep -q 'com.docker.swarm.service.name' ; then
                    local _service=${_label#*=}
                    echo $_service
                    return
                fi
            done
        fi
    done
}

# Find all service relative to a stack
# $1 -> stack
# r -> my_stack_async,my_stack_db
function findAllServicesOfStack {
    local _stack=$1
    docker service ls -q --filter "label=com.docker.stack.namespace=$_stack" --format '{{printf "%s"  .Name }}' | tr '\n' ',' | sed 's/,$//'
}

# Find all task running on the same host relative to a service
# $1 -> my_stack_service
# r -> my_stack_async.1.p68azjagjt6vd5av0bxuxxt9s,my_stack_async.1.pfgdhfjhmkhtyrtgerfedas7t
function findTaskOnHostOfService {
    local _service=$1
    docker container ls -q --filter "label=com.docker.swarm.service.name=$_service" --format '{{printf "%s"  .Names }}' | tr '\n' ',' | sed 's/,$//'
}

# Find all the mount points of a service
# $1 -> service
# r -> volnam1:/mnt/,volnam2:/mnt2/
function findMountpoints {
    _my_service="$1"
    _label="$2"
		for _service in $(docker service ls --format '{{print .Name}}') ; do
        if [ $_my_service == $_service ] ; then 
                docker service inspect $_service --format='{{range  .Spec.TaskTemplate.ContainerSpec.Mounts }}{{ printf "%s:%s," .Source .Target }}{{ end }}' | sed 's/,$//'
        fi
    done
}

# Find the task of the own service
# r -> my_stack_async.1.p68azjagjt6vd5av0bxuxxt9s 
function findMyTaskName {
    for _container in $(docker ps --format '{{printf "%s;%s" .ID .Labels}}' | tr -d ' ') ; do
        if [ "${_container%;*}" == $(hostname -s) ] ; then
            for _label in $(echo ${_container#*;} | tr ',' '\n') ; do
                if echo $_label | grep -q 'com.docker.swarm.task.name' ; then
                    local _nodeName=${_label#*=}
                    echo $_nodeName
                fi
            done
        fi
    done
}

# Find the nodes (host) where the service is running in comma separated 
# $1 -> service
# r -> node1.local,node2.local
function findRunningNodes {
    _service="$1"
    docker service ps $_service --format '{{ .Node}}' | tr '\n' ',' | sed 's/,$//'
}

# Find the string that contains all the running tasks of a service
# $1 -> name of the service
# r -> my_stack_db.1.p68azjagjt6vd5av0bxuxxt9s,my_stack_db.2.mue01vc7a8qanphqxlg749pdw
function findServiceTasks {
    local _service=$1
    docker service ps --no-trunc -f "desired-state=running" $_service --format '{{printf "%s.%s"  .Name .ID }}' | tr ' ' ',' | sed 's/,$//'
}

# create certificate for csync2
function createCertificate {
    openssl genrsa -out /etc/csync2_ssl_key.pem 1024
    ls -l /etc/csync2_ssl_key.pem
    openssl req -batch -new -key /etc/csync2_ssl_key.pem -out /etc/csync2_ssl_cert.csr
    ls -l /etc/csync2_ssl_cert.csr
    openssl x509 -req -days 3600 -in /etc/csync2_ssl_cert.csr -signkey /etc/csync2_ssl_key.pem -out /etc/csync2_ssl_cert.pem
    ls -l /etc/csync2_ssl_cert.pem
}
###
# create csync2 cfg
# $1 -> conf dir
# $2 -> node string
# $3 -> key file
# $4 -> dir string
function createCsyncConfig {
    local _csync2CfgDir="$1"
    local _nodesString="$(echo $2 | tr ',' '\n')"
    local _keyFile="$3"
    local _dirsString="$4"
    mkdir -p $_csync2CfgDir
    for __host in $_nodesString ; do
        local _csync2CfgFile="$_csync2CfgDir/csync2_$(echo ${__host} | tr -d '._-').cfg"
        echo -e "group mycluster \n{" > $_csync2CfgFile
        for _host in $_nodesString ; do
            if [  "$_host" != "$__host" ] ; then
                    # host slave
                    echo    "    host ($_host);"   >> $_csync2CfgFile
            else
                    # host master
                    echo    "    host $_host;"   >> $_csync2CfgFile
            fi
        done
        echo    "    key $_keyFile;"  >> $_csync2CfgFile
        for _dir in $(echo $_dirsString | tr ',' '\n') ; do
            echo    "    include $_dir;" >> $_csync2CfgFile
        done
        echo    "    exclude *~;" >> $_csync2CfgFile
        echo    "}"                  >> $_csync2CfgFile
    
        echo "Wrote \"$_csync2CfgFile\""
    done
}

# create the lsync configuration
# $1 -> $lsyncdCfgFile position of the file
# $2 -> $nodeName 
# $3 -> /mnt/data1,/mnt/data2 directories to sync
# $r -> null
function createLsyncConf {
    local _lsyncdCfgFile=$1
    local _nodeName=$2
    local _dirsString=$3
    _confName=$(echo $_nodeName | tr -d '._-')

    echo "configuration name: $_confName"
cat << EOF > $_lsyncdCfgFile
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
                spawn(elist, "/usr/sbin/csync2", "-x", "-C", config.syncid, "-N", "$_nodeName")
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
                spawn(event, "/usr/sbin/csync2", "-C", config.syncid, "-xr", "-N", "$_nodeName")
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
$(for _dir in $(echo $_dirsString | tr ',' '\n') ; do echo "        [\"$_dir\"] = \"$_confName\","; done)
}
for key, value in pairs(sources) do
        sync {initSync, source=key, syncid=value}
end
EOF

    echo "Wrote \"$_lsyncdCfgFile\""
}

# Find Volumes to sync of a specific service
# $1 -> service 
# $2 -> label 
# r -> wp_content_async,db_data
function findValueByLabel {
    _my_service="$1"
    _label="$2"
		for _service in $(docker service ls --format '{{print .Name}}') ; do
        if [ $_my_service == $_service ] ; then 
            docker service inspect $_service  --format="{{ index .Spec.Labels \"$_label\"}}"
            return
        fi
    done
}

