#!/bin/bash

echo '=========================' `basename $0` args:$*: '=========================='

#set -x

function setup() {
    set -a 

    if test -f /etc/environment
    then
        . /etc/environment
    fi

    # Pull in the environment if it hasn't already been set. Should be only when a fleet service calls this.
    if test "$adNimbusDir" == ""
    then
        . /home/core/ad-nimbus/adNimbusEnvironment
    fi

    # TODO: Is it worth the time to make .coreosProfile readable by scripts called from fleet service files
    # For now only sourcing if this is an interactive terminal session (not fleet)
    if [ -z $PS1 ]
    then
        . "$adNimbusDir"/.coreosProfile
    else
        . "$adNimbusDir"/.sharedProfile
    fi

    registrySavesDir="$adNimbusDir/registrySaves"
    if test ! -d "$registrySavesDir"
    then
        mkdir -p "$registrySavesDir"
    fi

    timestampFile="$registrySavesDir/.startTar"

    set +a
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
        if test "`rundocker images | grep $svc`" != ""
        then
            continue
        fi

        if test ! -f "$imageTarGz"
        then
            pullImage $$DOCKER_USER/$svc:$svc
        else
            echo `date`'('$COREOS_PRIVATE_IPV4'):' rundocker load -i "$imageTarGz"
            rundocker load -i "$imageTarGz"
        fi
    done
    
    echo
    rundocker images
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
    echo `date`'('$COREOS_PRIVATE_IPV4'):' rundocker pull $image
    rundocker pull $image
}

function saveImage() {
    svcsToSave=$1
    if test "$svcsToSave" == "" -o "$svcsToSave" == "all"
    then
        svcsToSave=`rundocker ps | awk '{print $NF}' | grep -v NAMES`
    fi

    for svc_instance in $svcsToSave
    do 
        svc=`echo $svc_instance | sed 's/_.*//'`
        imageTar="$registrySavesDir/${svc}.tar"

        if test "`doWeCreateTarFile $imageTar`" == "true"
        then
            image=$DOCKER_USER/$svc:$svc
            echo `date`'('$COREOS_PRIVATE_IPV4'):' rundocker save -o $imageTar $image
            rundocker save -o $imageTar $image
            gzip -f $imageTar
        fi
    done

    listRegistrySaves
}

function saveAllImages() {
    # When we save all images on all instances, the same image can be loaded on different instances. Rather than tar the image
    # multiple times, create a file whose modification time indicates that saveAllImages is running.
    touch "$timestampFile" 

    for ipAddr in `getIpAddrsInCluster`
    do 
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
        image="$DOCKER_USER/$svc:$svc"

        if test ! -f "$imageTarGz"
        then
            pullImage $image
        else
            echo `date`'('$COREOS_PRIVATE_IPV4'):' cat $imageTarGz '|' rundocker import - $image
            cat $imageTarGz | rundocker import - $image
        fi
    done
    
    echo
    rundocker images
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
        svcsToExport=`rundocker ps | awk '{print $NF}' | grep -v NAMES`
    fi

    for svc_instance in $svcsToExport
    do
        svc=`echo $svc_instance | sed 's/_.*//'`
        imageTar="$registrySavesDir/${svc}_export.tar"

        if test "`doWeCreateTarFile $imageTar`" == "true"
        then
            rundocker commit $svc_instance $DOCKER_USER/$svc:$svc
            echo `date`'('$COREOS_PRIVATE_IPV4'):' rundocker export $svc_instance '>' "$imageTar"
            rundocker export $svc_instance > "$imageTar"
            gzip -f $imageTar
        fi
    done

    listRegistrySaves
}

function exportAllContainers() {
    touch "$timestampFile"

    for ipAddr in `getIpAddrsInCluster`
    do 
        ssh $ipAddr "$adNimbusDir"/adnimbus_registry/startAdNimbusRegistry.sh exportContainer all
    done
   
    rm -f "$timestampFile" 

    listRegistrySaves
}

function listDockerImages() {
    echo
    echo `date`'('$COREOS_PRIVATE_IPV4'):' rundocker images
    rundocker images
}

function clearImages() {
    imagesToClear=$1
    if test "$imagesToClear" == "" -o "$imagesToClear" == "all"
    then
        containersToClear=`rundocker ps | grep -v 'IMAGE' | awk '{print $1}'`
        if test "$containersToClear" != ""
        then
            rundocker rm -f $containersToClear
            rundocker ps -a
        fi

        imagesToClear=`rundocker images | grep -v 'IMAGE ID' | awk '{print $3}'`
    fi

    for imageId in $imagesToClear
    do
        echo $svc
        echo `date`'('$COREOS_PRIVATE_IPV4'):' rundocker rmi -f $imageId
        rundocker rmi -f $imageId
    done

    listDockerImages
}

function clearAllImages() {
    for ipAddr in `getIpAddrsInCluster`
    do 
        ssh $ipAddr "$adNimbusDir"/adnimbus_registry/startAdNimbusRegistry.sh clearImages all
    done
}


function startDocker() { 
    # Bind to only the internal VM to prevent the registry port becoming generally available
    rundocker run \
        --rm \
        --name=${adNimbusRegistryService}_$instance \
        -p ${COREOS_PRIVATE_IPV4}:${adNimbusRegistryGuestOsPort}:${adNimbusRegistryContainerPort} \
        --volume=$adNimbusDir/registry-dev:/registry-dev \
        ${DOCKER_USER}/${adNimbusRegistryService}:${adNimbusRegistryDockerTag}
}

function start() {
    importContainer adnimbus_registry

    startDocker
}

# TODO: Should this be moved to startAdNimbusRegistry.sh
function loadprivateregistry() {
    for i in $currentContainers
    do  
        rundocker pull $DOCKER_USER/$i:$i
        rundocker tag $DOCKER_USER/$i:$i localhost:5000/$i:$i; 
        rundocker push localhost:5000/$i:$i; 
    done
}

if test "$1" == "-d"
then
    set -x
    shift 1
fi

setup

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

