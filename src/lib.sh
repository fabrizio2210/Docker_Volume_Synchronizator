
#VOLUMES
# /etc
# /var/lib/csync2
# /opt/dataN

# Constants
csync2CfgDir=/etc/
lsyncdCfgFile=/etc/lsyncd/lsyncd.conf.lua
keyFile=/etc/csync2.key


###
function findService {
    for _container in $(docker ps --format '{{printf "%s;%s" .ID .Labels}}' | tr -d ' ') ; do
        if [ "${_container%;*}" == $(hostname -s) ] ; then
            for _label in $(echo ${_container#*;} | tr ',' '\n') ; do
                if echo $_label | grep -q 'com.docker.swarm.service.name' ; then
                    local _service=${_label#*=}
                    echo $_service
                fi
            done
        fi
    done
}

function findNodeName {
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


# Finde the string that contains all the nodes
# $1 -> name of the service
function findNodeString {
    local _service=$1
    local _nodesString=$(docker service ps --no-trunc -f "desired-state=running" $_service --format '{{printf "%s.%s"  .Name .ID }}')
    echo $_nodesString
}


###
# create csync2 cfg
# $1 -> conf dir
# $2 -> node string
# $3 -> key file
# $4 -> dir string
function createCsyncConfig {
    local _csync2CfgDir="$1"
    local _nodesString="$2"
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

