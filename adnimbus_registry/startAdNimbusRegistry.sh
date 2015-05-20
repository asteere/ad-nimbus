#!/bin/bash

#set -x

echo Warning: `basename $0` has not been used in awhile. Check for bugs.

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
    cd "$adNimbusDir"
}

function load {
    for imageTar in $currentContainers
    do
        imageTar="$adNimbusDir/registrySaves/$svc.tar.gz"
        imageTarGz="${imageTar}.gz"
        if test "`$myDocker images | grep $svc`" == ""
        then
            echo `date`'('$COREOS_PUBLIC_IPV4'):' $myDocker load -i "$imageTarGz"
            $myDocker load -i "$imageTarGz"
        fi
    done
    
    $myDocker images
}

function save() {
    cdad

    for svc in $currentContainers
    do 
        imageTar="$adNimbusDir/registrySaves/$svc.tar"
        $myDocker save -o $imageTar $DOCKER_REGISTRY/$svc:$svc
        gzip $imageTar
    done

    $myDocker images
}

function clear {
    . "$adNimbusDir"/.coreosProfile

    fdestroy

    cdad
    for svc in $currentContainers
    do
        echo $svc
        $myDocker rmi -f $DOCKER_REGISTRY/$svc:$svc
    done
    
    $myDocker images
}

function startDocker() { 
    # Bind to only the internal VM to prevent the registry port becoming generally available
    $myDocker run \
        --rm \
        --name=${adNimbusRegistryService}_$instance \
        -p ${COREOS_PUBLIC_IPV4}:${adNimbusRegistryGuestOsPort}:${adNimbusRegistryContainerPort} \
        -v $adNimbusDir/registry-dev:/registry-dev \
        ${DOCKER_REGISTRY}/${adNimbusRegistryService}:${adNimbusRegistryDockerTag}
}

function start() {
    load

    startDocker
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

