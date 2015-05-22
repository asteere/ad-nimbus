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
    /usr/bin/docker kill -s $1 ${confdService}_$instance
}

function start() {
    /usr/bin/docker run \
        --name=${confdDockerTag}_${instance} \
        --rm=true \
        -e "HOST_IP=${COREOS_PUBLIC_IPV4}" \
        -p ${COREOS_PUBLIC_IPV4}:${confdGuestOsPort}:${confdContainerPort} \
        --volume=/var/run/docker.sock:/var/run/docker.sock \
        --volume="$adNimbusDir"/${confdService}:${confdDir} \
        --volume="$adNimbusDir"/${nginxService}:${nginxDir} \
        --volume="$adNimbusTmp":${tmpDir} \
        ${DOCKER_REGISTRY}/${confdService}:${confdDockerTag} \
        /etc/confd/confd \
        -backend=${consulService} \
        -confdir=${confdDir} \
        --log-level=debug \
        -watch=true \
        -interval=${confdCheckInterval} \
        -node=${COREOS_PUBLIC_IPV4}:${consulHttpPort}
}

function stop() {
    sendSignal SIGTERM
}

functionName=$1
shift 1

instance=$1
shift 1

setup

set -x

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi

