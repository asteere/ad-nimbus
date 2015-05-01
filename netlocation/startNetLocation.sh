#! /bin/bash

# Start the docker container
# Figure out what port was forwarded
# Set the netlocation consul key
# Upon termination remove the consul key, send the signal to docker

function setup() {
    trap 'cleanup TERM' TERM
    trap 'cleanup INT' INT 
    trap 'cleanup QUIT' QUIT 
    trap 'cleanup HUP' HUP
    trap 'cleanup USR1' USR1

    set -a
        
    for envFile in /etc/environment /home/core/share/adNimbusEnvironment 
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

    set +a
}

function setKeyValue() {
    key=$1
    value=$2

    /usr/bin/curl -v -s -X PUT -d $value http://${COREOS_PUBLIC_IPV4}:${consulHttpPort}/v1/kv${key}
    
    dumpConsulKeys
}

function removeKeyValue() {
    key=$1

    /usr/bin/curl -v -s -X DELETE http://${COREOS_PUBLIC_IPV4}:${consulHttpPort}/v1/kv${key}

    dumpConsulKeys
}

function dumpConsulKeys() {
    /usr/bin/curl -v -s -L -X GET http://${COREOS_PUBLIC_IPV4}:${consulHttpPort}/v1/kv/?recurse
}

function createNetLocationConsulKey() {
    netLocationConsulKey=`echo ${netLocationKey}/${COREOS_PUBLIC_IPV4}/$instance`
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
            netLocationConsulValue="${COREOS_PUBLIC_IPV4}:$netLocationGuestOsPort"
            break
        fi
        sleep 2
    done
}

function registerService() {
    port=$1

    /home/core/share/monitor/monitor.sh registerNetLocationService $instance ${COREOS_PUBLIC_IPV4} $port
}

function startNetLocation() {
    # From: https://github.com/coreos/fleet/issues/612
    /usr/bin/docker run \
        --name=${containerName} \
        --rm=true \
        -P \
        -v /home/core/share/${netLocationService}/src:/src \
        ${DOCKER_REGISTRY}/${netLocationService}:${netLocationDockerTag} \
        /src/startNpm.sh ${COREOS_PUBLIC_IPV4}
}

function cleanup() {
    signal=$1
    if test "$signal" == ""
    then
        signal=KILL
    fi

    echo Sending $signal to netlocation 

    docker kill -s $signal $containerName

    docker rm -f ${containerName}

    createNetLocationConsulKey $instance

    removeKeyValue $netLocationConsulKey

    /home/core/share/monitor/monitor.sh unregisterNetLocationService $instance ${COREOS_PUBLIC_IPV4}
}

function registerNetLocation() {
    createNetLocationConsulKey $instance

    createNetLocationConsulValue $containerName

    setKeyValue $netLocationConsulKey $netLocationConsulValue

    registerService $netLocationGuestOsPort
}

if test "$1" == "-d"
then
    set -x
    shift 1
fi

usage="Usage: `basename $0` functionName netLocationInstanceNumber"
if test "$#" -ne "2"
then
    echo $usage
    exit 1
fi

setup

functionName=$1
instance=$2
containerName=${netLocationDockerTag}_$instance 

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} 
    exit 0
fi

return 2>/dev/null || echo $usage && exit 1

