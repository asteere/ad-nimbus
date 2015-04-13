#! /bin/bash

set -e

. /etc/environment
. ~/share/adNimbusEnvironment

set +e

hostname=`uname -n`


# Get number of coreos instances
numServers=`grep '$num_instances=' config.rb | sed 's/.*=//'`

# Get number instances of consul running
# TODO: Start the right number of consul agents and servers based on cluster size
numInstances=`fleetctl list-unit-files -fields=unit | grep -v UNIT | wc -l`
numInstances=1

serverArg=-server

case "$numInstances" in
0)
    # TODO: do we want to always remove all the data. Probably only when we start the cluster the first time
    rm -rf ~/share/consul/data/*
    bootstrapArg="-bootstrap-expect $numServers" 

    # start the server
    advertise=${COREOS_PUBLIC_IPV4}
;;
1,2)
    # start additional servers, no ui

    # TOOD: Figure out the IP addr of the first server
    join=172.17.8.101

    uiDir="-ui-dir ${consulDir}/ui"
;;
*)
    unset serverArg
    uiDir="-ui-dir ${consulDir}/ui"
;;
esac

# Find the smallest odd number greater than 1
# If the number instances in less expected servers, start another
# Otherwise, start agent with UI

#    -p ${COREOS_PRIVATE_IPV4}:8300:8300 \
#    -p ${COREOS_PRIVATE_IPV4}:8301:8301 \
#    -p ${COREOS_PRIVATE_IPV4}:8301:8301/udp \
#    -p ${COREOS_PRIVATE_IPV4}:8302:8302 \
#    -p ${COREOS_PRIVATE_IPV4}:8302:8302/udp \
#    -p ${COREOS_PRIVATE_IPV4}:53:53/udp \

/usr/bin/docker run --name=${consulDockerTag} --rm=true -e "HOST_IP=${COREOS_PUBLIC_IPV4}" \
    --hostname=$hostname \
    -p ${COREOS_PUBLIC_IPV4}:${consulGuestOSPort}:${consulContainerPort} \
    -p ${COREOS_PRIVATE_IPV4}:8400:8400 \
    -p ${COREOS_PRIVATE_IPV4}:8500:8500 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /home/core/share/${consulService}:${consulDir} \
    -v /home/core/share/${nginxService}:${nginxDir} \
    ${consulDockerRegistry}/${consulService}:${consulDockerTag} \
    ${consulDir}/${consulService} \
    agent $serverArg $uiDir\
    -config-dir ${consulDir}/consul.d $bootstrapArg\
    -node $hostname \
    -data-dir ${consulDir}/data
