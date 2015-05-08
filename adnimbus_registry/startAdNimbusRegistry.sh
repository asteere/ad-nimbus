#!/bin/bash

#set -x

set -a 
. /etc/environment
. /home/core/share/adNimbusEnvironment
set +a

function cdad() {
    cd "$AD_NIMBUS_DIR"
}

function loadregistry {
    cdad
    for imageTar in $currentContainers
    do
        echo `date`: $myDocker load -i registrySaves/${imageTar}.tar
        $myDocker load -i registrySaves/${imageTar}.tar
    done
    
    $myDocker images
}

function saveregistry() {
    cdad
    for svc in $currentContainers
    do 
        $myDocker save -o registrySaves/$svc.tar $DOCKER_REGISTRY/$svc:$svc
    done

    $myDocker images
}

function clearregistry {
    . "$AD_NIMBUS_DIR"/.coreosProfile

    fdestroy

    cdad
    for svc in $currentContainers
    do
        echo $svc
        $myDocker rmi -f $DOCKER_REGISTRY/$svc:$svc
    done
    
    $myDocker images
}

function loadadnimbusregistry() {
    if test "`$myDocker images | grep $adNimbusRegistryService`" == ""
    then
        echo $myDocker load -i "$AD_NIMBUS_DIR"/registrySaves/${adNimbusRegistryService}.tar
        $myDocker load -i "$AD_NIMBUS_DIR"/registrySaves/${adNimbusRegistryService}.tar
    fi
}

function startadnimbusregistry() { 
    $myDocker run \
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
    myDocker=/usr/bin/docker
    AD_NIMBUS_DIR=/home/core/share
else
    myDocker=runDocker
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

