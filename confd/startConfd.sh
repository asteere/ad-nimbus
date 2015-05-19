#!/bin/bash

echo `basename $0` args:$*:

function setup() {
    set -a
    . /etc/environment
    . /home/core/share/adNimbusEnvironment
    set +a

    trap 'sendSignal SIGTERM' TERM
    trap 'sendSignal SIGQUIT' QUIT
    trap 'sendSignal USR1' USR1
}

# TODO: Is this needed?
function sendSignal() {
    echo Sending $1 to $confdService
    /usr/bin/docker kill -s SIGTERM ${confdService}_$instance
}

function start() {
    /usr/bin/docker run \
        --name=${confdDockerTag}_${instance} \
        --rm=true \
        -e "HOST_IP=${COREOS_PUBLIC_IPV4}" \
        -p ${COREOS_PUBLIC_IPV4}:${confdGuestOsPort}:${confdContainerPort} \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v "$adNimbusDir"/${confdService}:${confdDir} \
        -v "$adNimbusDir"/${nginxService}:${nginxDir} \
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

function stop() {
    sendSignal SIGTERM
}

functionName=$1
instance=$2

setup

set -x

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi

