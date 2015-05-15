#!/bin/bash

#set -x

function setup() {
    set -a 

    if test "`uname -s`" == "Linux"
    then
        myDocker=/usr/bin/docker
    else
        myDocker=runDocker
    fi

    . /etc/environment
    . /home/core/share/adNimbusEnvironment

    set +a
}

function cdad() {
    cd "$AD_NIMBUS_DIR"
}

function load {
    for imageTar in $currentContainers
    do
        if test "`$myDocker images | grep $imageTar`" == ""
        then
            echo `date`'('$COREOS_PUBLIC_IPV4'):' $myDocker load -i "$AD_NIMBUS_DIR"/registrySaves/${imageTar}.tar
            $myDocker load -i "$AD_NIMBUS_DIR"/registrySaves/${imageTar}.tar
        fi
    done
    
    $myDocker images
}

function save() {
    cdad
    for svc in $currentContainers
    do 
        $myDocker save -o registrySaves/$svc.tar $DOCKER_REGISTRY/$svc:$svc
    done

    $myDocker images
}

function clear {
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

function start() { 
    # Bind to only the internal VM to prevent the registry port becoming generally available
    $myDocker run \
        --rm \
        --name=${adNimbusRegistryService}_$instance \
        -p ${COREOS_PUBLIC_IPV4}:${adNimbusRegistryGuestOsPort}:${adNimbusRegistryContainerPort} \
        -v $AD_NIMBUS_DIR/registry-dev:/registry-dev \
        ${DOCKER_REGISTRY}/${adNimbusRegistryService}:${adNimbusRegistryDockerTag}
}

function start() {
    loadadnimbusregistry

    startadnimbusregistry
}

setup

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

echo `basename $0` '[load | start | all ]' instance

