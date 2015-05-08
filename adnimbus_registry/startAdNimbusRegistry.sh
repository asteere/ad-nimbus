#!/bin/bash

#set -x

set -a 
. /etc/environment
. /home/core/share/adNimbusEnvironment
set +a

function loadadnimbusregistry() {
    if test "`$mydocker images | grep $adNimbusRegistryService`" == ""
    then
        echo $mydocker load -i "$AD_NIMBUS_DIR"/registrySaves/${adNimbusRegistryService}.tar
        $mydocker load -i "$AD_NIMBUS_DIR"/registrySaves/${adNimbusRegistryService}.tar
    fi
}

function startadnimbusregistry() { 
    $mydocker run \
        --rm \
        --name=${adNimbusRegistryService}_$instance \
        -p ${adNimbusRegistryGuestOsPort}:${adNimbusRegistryContainerPort} \
        -v $AD_NIMBUS_DIR/registry-dev:/registry-dev \
        ${DOCKER_REGISTRY}/${adNimbusRegistryService}:${adNimbusRegistryDockerTag}
}

function start() {
    loadadnimbusregistry

    startadnimbusregistry
}

if test "`uname -s`" == "Linux"
then
    mydocker=/usr/bin/docker
    AD_NIMBUS_DIR=/home/core/share
else
    mydocker=runDocker
fi

functionName=$1
instance=$2

if test "$instance" == ""
then
    instance=1
fi

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi

echo `basename $0` '[loadadnimbusregistry | startadnimbusregistry | all ]' instance

