
RC=0
image=docker_volume_synchronizer
service=test-docker
network=sync-network
set -x
docker build -t $image -f docker/x86_64/Dockerfile .
let RC=$RC+$?
docker swarm init
docker network create --driver overlay $network
docker service create --detach=false --network $network --name $service --replicas 2 --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock $image wrapper.sh -k y7laMv1RAIJOWft3nRKmHnBYCptjEmNKQ8OrpaltFC1fLneJjmLwe96VEaOla5en -d /opt/data/
let RC=$RC+$?
i=0
for cont in $(docker container ls --format '{{ printf "%s;%s"  .ID .Image }}' | grep $image ) ; do
    if [ $i -gt 0 ] ; then
        let j=$i-1
        if [ "$rand" == "$(docker exec -ti ${cont%;*} cat /opt/data/prova$j | tr -d '\r')" ] ; then
            echo "SUCCESS"
        else
            echo "FAILURE"
            let RC=$RC+1
        fi
    fi
    rand=$RANDOM
    docker exec -ti ${cont%;*} sh -c "echo $rand > /opt/data/prova$i"
    sleep 6
    let i=$i+1
done
docker service rm $service

exit $RC
