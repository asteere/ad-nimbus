#! /bin/bash

set -e

. /etc/environment
. ~/share/adNimbusEnvironment

set +e

hostname=`uname -n`

export GOMAXPROCS=8

# Get number of coreos instances. This works as long as all machines are running etcd ?servers?
# 
# numServers=`curl http://127.0.0.1:4001/v2/keys/_etcd/machines | $AD_NIMBUS_DIR/jq '.node.nodes[].value' | wc -l`
numServers=`etcdctl ls -recursive _etcd/machines | wc -l`

echo etcd reported $numServers servers

# TODO: Override results while in initial development
numServers=2

# Get number instances of consul running
# TODO: Start the right number of consul agents and servers based on cluster size
numInstances=`fleetctl list-unit-files -fields=unit | grep -v UNIT | wc -l`
numInstances=$1

# Not sure why but use the eth0 IP addr
ETH0_ADDR=${COREOS_PUBLIC_IPV4}

dataCenterArg="-dc superior-dc"

serverArg=-server
advertiseArg="-advertise=${COREOS_PUBLIC_IPV4}"
bindArg="-bind=${COREOS_PUBLIC_IPV4}"
clientArg="-client=${COREOS_PUBLIC_IPV4}"

# TODO: figure out how to get the IP address of the first consul so everybody can join it
FIXTHIS_IPV4="172.17.8.101"
joinArg="-join=$FIXTHIS_IPV4"

nodeArg="-node $hostname"

# TODO: Do all the consul servers and agents needs the UI or only some portion
uiDirArg="-ui-dir ${consulDir}/ui"

dataDirArg="-data-dir /tmp/consul"
configDirArg="-config-dir ${consulDir}/consul.d"

case "$numInstances" in
0)
    # start the first server

    bootstrapArg="-bootstrap"

    unset joinArg    
    
;;
1|2)
    # start additional servers
;;
*)
    unset serverArg
;;
esac

# Find the smallest odd number greater than 1
# If the number instances in less expected servers, start another
# Otherwise, start agent with UI

# TODO: do we want to always remove all the data. Probably only when we start the cluster the first time
rm -rf /tmp/data

set -x

/usr/bin/docker run --name=${consulDockerTag} --rm=true -e "HOST_IP=${COREOS_PUBLIC_IPV4}" \
    --hostname=$hostname \
    -p ${COREOS_PUBLIC_IPV4}:8300:8300 \
    -p ${COREOS_PUBLIC_IPV4}:8301:8301 \
    -p ${COREOS_PUBLIC_IPV4}:8301:8301/udp \
    -p ${COREOS_PUBLIC_IPV4}:8302:8302 \
    -p ${COREOS_PUBLIC_IPV4}:8302:8302/udp \
    -p ${COREOS_PUBLIC_IPV4}:8400:8400 \
    -p ${COREOS_PUBLIC_IPV4}:8500:8500 \
    -p ${COREOS_PUBLIC_IPV4}:53:53/udp \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/core/share/${consulService}:${consulDir} \
    -v /home/core/share/${nginxService}:${nginxDir} \
    ${consulDockerRegistry}/${consulService}:${consulDockerTag} \
    ${consulDir}/${consulService} \
    agent $serverArg $bootstrapArg $advertiseArg $joinArg $bindArg $clientArg \
    $dataCenterArg \
    $uiDirArg $configDirArg \
    $dataDirArg \
    $nodeArg

