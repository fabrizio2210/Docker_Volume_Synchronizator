#./init.sh -l bananam2u1.oss@proxi1,bananam2u0.oss@proxy2 -n bananam2u0.oss -k y7laMv1RAIJOWft3nRKmHnBYCptjEmNKQ8OrpaltFC1fLneJjmLwe96VEaOla5en -d /opt/data/,/root/test-csync/inSync/ -a "{ \"root:toor\" : [\"\"] }"

set -x
cd ..
docker build -t fabrizio2210/docker_volume_synchronizer -f docker/x86_64/Dockerfile .
docker network create --driver overlay sync-network
docker service create --network sync-network --name test-docker --replicas 2 --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock fabrizio2210/docker_volume_synchronizer wrapper.sh -k y7laMv1RAIJOWft3nRKmHnBYCptjEmNKQ8OrpaltFC1fLneJjmLwe96VEaOla5en -d /opt/data/
i=0
for cont in $(docker container ls --format '{{ printf "%s;%s"  .ID .Image }}' | grep docker_volume_synchronizer ) ; do
    if [ $i -gt 0 ] ; then
        let j=$i-1
        if [ "$rand" == "$(docker exec -ti ${cont%;*} cat /opt/data/prova$j | tr -d '\r')" ] ; then
            echo "SUCCESS"
        fi
    fi
    rand=$RANDOM
    docker exec -ti ${cont%;*} sh -c "echo $rand > /opt/data/prova$i"
    sleep 6
    let i=$i+1
done
docker service rm test-docker
cd src
