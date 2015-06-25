#! /bin/bash

# Start the docker container
# Figure out what port was forwarded
# Set the netlocation consul key
# Upon termination remove the consul key, send the signal to docker

echo "==================== `basename $0` started args:$*: ======================="
set -x

function setup() {
    echo `basename $0` in setup

    trap 'cleanup TERM' TERM
    trap 'cleanup INT' INT 
    trap 'cleanup QUIT' QUIT 
    trap 'cleanup HUP' HUP
    trap 'cleanup USR1' USR1

    set -a
        
    for envFile in /etc/environment /home/core/ad-nimbus/adNimbusEnvironment /home/core/ad-nimbus/.sharedProfile
    do  
        if test ! -f "$envFile"
        then
            echo Error: Unable to find envFile $envFile
            exit 1
        fi
        . "$envFile"
    done

    netLocationConsulKey=-1
    netLocationConsulValue=-1
    netLocationGuestOsPort=-1

    if test "$netLocationImplementation" == "go"
    then
        dockerCmd="/netlocation/bin/netlocation"
    else
        dockerCmd="/src/startNpm.sh"
    fi
    dockerCmd="$dockerCmd ${COREOS_PRIVATE_IPV4} $instance"
    svc=${netLocationService}-${netLocationImplementation}
    dockerImage=$svc:${netLocationDockerTag}-${netLocationImplementation} 
    dockerRepoImage=${DOCKER_USER}/$dockerImage

    set +a
}

function setKeyValue() {
    key=$1
    value=$2

    curl -v -s -X PUT -d $value http://${COREOS_PRIVATE_IPV4}:${consulHttpPort}/v1/kv${key}
    
    dumpConsulKeys
}

function removeKeyValue() {
    key=$1

    curl -v -s -X DELETE http://${COREOS_PRIVATE_IPV4}:${consulHttpPort}/v1/kv${key}

    dumpConsulKeys
}

function dumpConsulKeys() {
    curl -v -s -L -X GET http://${COREOS_PRIVATE_IPV4}:${consulHttpPort}/v1/kv/?recurse
}

function createNetLocationConsulKey() {
    netLocationConsulKey=`echo ${netLocationKey}/${COREOS_PRIVATE_IPV4}/$instance`
}

function createNetLocationConsulValue() {
    containerName=$1

    # Get the ports from the docker image
    while true
    do
        netLocationGuestOsPort=`docker port $containerName | \
            grep $netLocationContainerPort | \
            sed -e 's/.*-> //' -e 's/.*://'`

        if test "$netLocationGuestOsPort" != ""
        then
            netLocationConsulValue="${COREOS_PRIVATE_IPV4}:$netLocationGuestOsPort"
            break
        fi
        sleep 5
    done
}

function registerService() {
    port=$1

    "$adNimbusDir"/monitor/monitor.sh registerNetLocationService $instance ${COREOS_PRIVATE_IPV4} $port
}

function loadContainers() {
    docker rm -f ${containerName} > /dev/null 2>&1
    $adNimbusDir/adnimbus_registry/startAdNimbusRegistry.sh startPre $svc

    docker ps | grep -q "$netLocationDataContainer"
    if test $? != 0
    then
        createnetlocationdatacontainer
    fi

    docker ps -a
}

function start() {
    loadContainers

    startDocker
}

function startDocker() {
    # From: https://github.com/coreos/fleet/issues/612
    #    -p 49170:8080 \
    # Use -P as multiple netlocation services can be started on the same OS. Don't want the ports to conflict.
    docker run \
        --name=${containerName} $interactive \
        --rm=true \
        --expose=$netLocationContainerPort \
        -P \
        --volumes-from $netLocationDataContainer \
        --volume="$adNimbusDir"/$netLocationService/$netLocationImplementation/src:/src \
        --volume="$adNimbusTmp":${tmpDir} \
        $dockerRepoImage \
        $dockerCmd

#        --volume="$adNimbusDir"/$netLocationService/data:/data \
}

function startDockerBash() {
    dockerCmd="bash $*"

    interactive="-it --privileged"

    startDocker
}

function cleanup() {
    echo Received signal $1

    signal=$1
    if test "$signal" == ""
    then
        signal=KILL
    fi

    echo Sending $signal to netlocation 

    docker kill -s $signal $containerName

    docker rm -f $containerName

    createNetLocationConsulKey $instance

    removeKeyValue $netLocationConsulKey

    "$adNimbusDir"/monitor/monitor.sh unregisterNetLocationService $instance ${COREOS_PRIVATE_IPV4}
}

function registerNetLocation() {
    createNetLocationConsulKey $instance

    createNetLocationConsulValue $containerName

    setKeyValue $netLocationConsulKey $netLocationConsulValue

    registerService $netLocationGuestOsPort
}

function stop() {
    if test "$instance" == ""
    then
        instance=$1
    fi

    docker kill -s KILL $containerName
}

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
else
    shift 1
fi
containerName=${netLocationService}_$instance 

setup

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi

return 2>/dev/null || echo $usage && exit 1

