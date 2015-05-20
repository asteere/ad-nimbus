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
    cd "$adNimbusDir"
}

function load {
    svcsToLoad=$1
    if test "$svcsToLoad" == ""
    then
        svcsToLoad=$currentContainers
    fi

    for svc in $svcsToLoad
    do
        imageTarGz="$adNimbusDir/registrySaves/$svc.tar.gz"
        if test "`$myDocker images | grep $svc`" == ""
        then
            echo `date`'('$COREOS_PUBLIC_IPV4'):' $myDocker load -i "$imageTarGz"
            $myDocker load -i "$imageTarGz"
        fi
    done
    
    echo
    $myDocker images
}

function save() {
    svcsToSave=$1
    if test "$svcsToSave" == ""
    then
        svcsToSave=$currentContainers
    fi

    for svc in $svcsToSave
    do 
        imageTar="$adNimbusDir/registrySaves/$svc.tar"
        $myDocker save -o $imageTar $DOCKER_REGISTRY/$svc:$svc
        gzip $imageTar
    done

    echo
    ls -l "$adNimbusDir"/registrySaves
}

function import {
    svcsToImport=$1
    if test "$svcsToImport" == ""
    then
        svcsToImport=$currentContainers
    fi

    # TODO: Can we get by with the assumption of there always being an instance 1
    instance=1

    for svc in $svcsToImport
    do
        imageTarGz="$adNimbusDir/registrySaves/${svc}_export.tar.gz"

        echo `date`'('$COREOS_PUBLIC_IPV4'):' cat $imageTarGz '|' $myDocker import - $DOCKER_REGISTRY/$svc:$svc
        cat $imageTarGz | $myDocker import - $DOCKER_REGISTRY/$svc:$svc
    done
    
    echo
    $myDocker images
}

function export {
    svcsToExport=$1
    if test "$svcsToExport" == ""
    then
        svcsToExport=$currentContainers
    fi

    # TODO: Can we get by with the assumption of there always being an instance 1
    instance=1

    for svc in $svcsToExport
    do
        imageTar="$adNimbusDir/registrySaves/${svc}_export.tar"
        if test "`$myDocker ps | grep $svc`" == ""
        then
            echo `date`'('$COREOS_PUBLIC_IPV4'):' $myDocker export ${svc}_$instance '>' "$imageTar"
            $myDocker export ${svc}_$instance > "$imageTar"
            gzip $imageTar
        fi
    done
    
    echo
    ls -l "$adNimbusDir"/registrySaves
}

function clear {
    imagesToClear=$1
    if test "$imagesToClear" == ""
    then
        imagesToClear=`$myDocker images | grep -v 'IMAGE ID' | awk '{print $3}'`
    fi

    for imageId in $imagesToClear
    do
        echo $svc
        $myDocker rmi -f $imageId
    done
    
    echo
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
    import adnimbus_registry

    startDocker
}

setup

if test "$1" == "-d"
then
    set -x
    shift 1
fi

functionName=$1
shift 1

instance=$1

if test "$instance" == ""
then
    instance=1
    shift 1
fi

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi

echo `basename $0` '[load | start | all ]' instance

