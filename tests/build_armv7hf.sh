
RC=0
image=docker_volume_synchronizer_armv7hf
set -x
docker build -t $image -f docker/armv7hf/Dockerfile .
let RC=$RC+$?

exit $RC
