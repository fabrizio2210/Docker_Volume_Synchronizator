# Docker_Volume_Synchronizator
A container that syncronizes volumes within a Swarm cluster in asynchroned way. In fact, there are some scenarios 
where you want keep synchronized some volume across the Swarm cluster. For example,
if you want ensure a simple high availability.

The files are synchronized with 3 seconds.

## Components
It is composed by Lsync and Csync2.

## Build
You can build the image giving the following commands:
```
git clone https://github.com/fabrizio2210/Docker_Volume_Synchronizator.git
cd Docker_Volume_Synchronizator
docker build -t docker_volume_sync -f docker/x86_64/Dockerfile .
```

## Prerequisities
The container works only in a docker Swarm cluster.

## Use
I suggest to create a dedicated network beacause the ingress network doesn't do the service discovery.
The service has to be created mounting the Docker socket (`/var/run/docker.sock`) and the volumes to synchronize.
Then, you should pass the mounted volume to the inside script `wrapper.sh`.
The arguments to pass to the `wrapper.sh` script are:
- `-d` the comma separated list of the directories to sync inside the container
- `-k` the base64 encoded password for Cysnc2 (it can be a random base64 string)

### Example
An example how this container should be use:

```
docker swarm init
docker network create --driver overlay network-sync
docker service create \
    --detach=false --network network-sync \
    --name volume-sync --mode global \
    --mount type=bind,source=/var/run/docker.sock,destination=/var/run/docker.sock \
    --mount type=bind,source=/mnt/async,destination=/opt/data \
    fabrizio2210/docker_volume_synchronizer \
    wrapper.sh -k fLneJmNKQ8OrpaltFC1y7laMv1RAIJOWftjmLwe96VEaOla5entjE3nRKmHnBYCp -d /opt/data/
```
