#!/bin/bash

set -a
. /etc/environment
set +a

functionName=$1
instance=$2

function start() {
    /usr/bin/docker run \
        --name=${confdDockerTag}_${instance} \
        --rm=true -e "HOST_IP=${COREOS_PUBLIC_IPV4}" \
        -p ${COREOS_PUBLIC_IPV4}:${confdGuestOsPort}:${confdContainerPort} \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /home/core/share/${confdService}:${confdDir} \
        -v /home/core/share/${nginxService}:${nginxDir} \
        ${DOCKER_REGISTRY}/${confdService}:${confdDockerTag} \
        /etc/confd/confd \
        -backend=${consulService} \
        -confdir=${confdDir} \
        -debug=true \
        -verbose=true \
        -watch=true \
        -interval=${confdCheckInterval} \
        -node=${COREOS_PUBLIC_IPV4}:${consulHttpPort}
}

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi

