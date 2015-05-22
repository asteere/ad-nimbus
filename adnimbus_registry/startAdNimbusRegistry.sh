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
    
    if [ -z $PS1 ]
    then
        . /home/core/share/.coreosProfile
    fi

    registrySavesDir="$adNimbusDir/registrySaves"
    if test ! -d "$registrySavesDir"
    then
        mkdir -p "$registrySavesDir"
    fi

    timestampFile="$registrySavesDir/.startTar"

    set +a
}

function cdad() {
    cd "$adNimbusDir"
}

function loadImage() {
    svcsToLoad=$1
    if test "$svcsToLoad" == ""
    then
        svcsToLoad=$currentContainers
    fi

    for svc in $svcsToLoad
    do
        imageTarGz="$registrySavesDir/$svc.tar.gz"
        if test "`$myDocker images | grep $svc`" != ""
        then
            continue
        fi

        if test ! -f "$imageTarGz"
        then
            pullImage $$DOCKER_REGISTRY/$svc:$svc
        else
            echo `date`'('$COREOS_PUBLIC_IPV4'):' $myDocker load -i "$imageTarGz"
            $myDocker load -i "$imageTarGz"
        fi
    done
    
    echo
    $myDocker images
}

function startPre() {
    # TODO: Why does starting an export not display any ports?
    # For now, use docker load 
    loadImage $* 
}

function doWeCreateTarFile() {
    imageTar=$1

    if test -f "$timestampFile" -a "$imageTar.gz" -nt "$timestampFile"  
    then
        echo false
    else
        echo true
    fi
}

function pullImage() {
    image=$1

    echo 'Pulling from dockerhub. Did you forget to save/export the containers after fstartall finished?'
    echo `date`'('$COREOS_PUBLIC_IPV4'):' $myDocker pull $image
    $myDocker pull $image
}

function saveImage() {
    svcsToSave=$1
    if test "$svcsToSave" == "" -o "$svcsToSave" == "all"
    then
        svcsToSave=`$myDocker ps | awk '{print $NF}' | grep -v NAMES`
    fi

    for svc_instance in $svcsToSave
    do 
        svc=`echo $svc_instance | sed 's/_.*//'`
        imageTar="$registrySavesDir/${svc}.tar"

        if test "`doWeCreateTarFile $imageTar`" == "true"
        then
            image=$DOCKER_REGISTRY/$svc:$svc
            echo `date`: $myDocker save -o $imageTar $image
            $myDocker save -o $imageTar $image
            gzip -f $imageTar
        fi
    done

    listRegistrySaves
}

function saveAllImages() {
    ipRoot=`getIpRoot`

    touch "$timestampFile" 

    instanceRange={1..$numInstances}
    for i in `eval echo $instanceRange`
    do 
        ipAddr=${ipRoot}.10$i
        ssh $ipAddr "$adNimbusDir"/adnimbus_registry/startAdNimbusRegistry.sh saveImage all
    done

    rm -f "$timestampFile" 

    listRegistrySaves
}

function importContainer() {
    svcsToImport=$1
    if test "$svcsToImport" == ""
    then
        svcsToImport=$currentContainers
    fi

    for svc in $svcsToImport
    do
        imageTarGz="$registrySavesDir/${svc}_export.tar.gz"
        image="$DOCKER_REGISTRY/$svc:$svc"

        if test ! -f "$imageTarGz"
        then
            pullImage $image
        else
            echo `date`'('$COREOS_PUBLIC_IPV4'):' cat $imageTarGz '|' $myDocker import - $image
            cat $imageTarGz | $myDocker import - $image
        fi
    done
    
    echo
    $myDocker images
}

function listRegistrySaves() {
    if test ! -f "$timestampFile"
    then
        echo
        ls -alt "$adNimbusDir"/registrySaves
    fi
}

function exportContainer() {
    svcsToExport=$1
    if test "$svcsToExport" == "" -o "$svcsToExport" == "all"
    then
        svcsToExport=`$myDocker ps | awk '{print $NF}' | grep -v NAMES`
    fi

    for svc_instance in $svcsToExport
    do
        svc=`echo $svc_instance | sed 's/_.*//'`
        imageTar="$registrySavesDir/${svc}_export.tar"

        if test "`doWeCreateTarFile $imageTar`" == "true"
        then
            $myDocker commit $svc_instance $DOCKER_REGISTRY/$svc:$svc
            echo `date`'('$COREOS_PUBLIC_IPV4'):' $myDocker export $svc_instance '>' "$imageTar"
            $myDocker export $svc_instance > "$imageTar"
            gzip -f $imageTar
        fi
    done

    listRegistrySaves
}

function exportAllContainers() {
    ipRoot=`getIpRoot`

    touch "$timestampFile"

    instanceRange={1..$numInstances}
    for i in `eval echo $instanceRange`
    do 
        ipAddr=${ipRoot}.10$i
        ssh $ipAddr "$adNimbusDir"/adnimbus_registry/startAdNimbusRegistry.sh exportContainer all
    done
   
    rm -f "$timestampFile" 

    listRegistrySaves
}

function listDockerImages() {
    echo
    echo `date`'('$COREOS_PUBLIC_IPV4'):' $myDocker images
    $myDocker images
}

function clearImages() {
    imagesToClear=$1
    if test "$imagesToClear" == "" -o "$imagesToClear" == "all"
    then
        containersToClear=`$myDocker ps | grep -v 'IMAGE' | awk '{print $1}'`
        if test "$containersToClear" != ""
        then
            $myDocker rm -f $containersToClear
            $myDocker ps -a
        fi

        imagesToClear=`$myDocker images | grep -v 'IMAGE ID' | awk '{print $3}'`
    fi

    for imageId in $imagesToClear
    do
        echo $svc
        echo `date`'('$COREOS_PUBLIC_IPV4'):' $myDocker rmi -f $imageId
        $myDocker rmi -f $imageId
    done

    listDockerImages
}

function clearAllImages() {
    ipRoot=`getIpRoot`

    instanceRange={1..$numInstances}
    for i in `eval echo $instanceRange`
    do 
        ipAddr=${ipRoot}.10$i
        ssh $ipAddr "$adNimbusDir"/adnimbus_registry/startAdNimbusRegistry.sh clearImages all
    done
}


function startDocker() { 
    # Bind to only the internal VM to prevent the registry port becoming generally available
    $myDocker run \
        --rm \
        --name=${adNimbusRegistryService}_$instance \
        -p ${COREOS_PUBLIC_IPV4}:${adNimbusRegistryGuestOsPort}:${adNimbusRegistryContainerPort} \
        --volume=$adNimbusDir/registry-dev:/registry-dev \
        ${DOCKER_REGISTRY}/${adNimbusRegistryService}:${adNimbusRegistryDockerTag}
}

function start() {
    importContainer adnimbus_registry

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

echo `basename $0` 'functionName instance'

