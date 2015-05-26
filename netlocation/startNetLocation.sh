#! /bin/bash

# Start the docker container
# Figure out what port was forwarded
# Set the netlocation consul key
# Upon termination remove the consul key, send the signal to docker

echo "==================== `basename $0` started args:$*: ======================="

function setup() {
    echo `basename $0` in setup

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

    /usr/bin/curl -v -s -X PUT -d $value http://${COREOS_PRIVATE_IPV4}:${consulHttpPort}/v1/kv${key}
    
    dumpConsulKeys
}

function removeKeyValue() {
    key=$1

    /usr/bin/curl -v -s -X DELETE http://${COREOS_PRIVATE_IPV4}:${consulHttpPort}/v1/kv${key}

    dumpConsulKeys
}

function dumpConsulKeys() {
    /usr/bin/curl -v -s -L -X GET http://${COREOS_PRIVATE_IPV4}:${consulHttpPort}/v1/kv/?recurse
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

function startDocker() {
    # From: https://github.com/coreos/fleet/issues/612
    #    -p 49170:8080 \
    # Use -P as multiple netlocation services can be started on the same OS. Don't want the ports to conflict.
    /usr/bin/docker run \
        --name=${containerName} $interactive \
        --rm=true \
        -P \
        --volume="$adNimbusDir"/${netLocationService}/src:/src \
        --volume="$adNimbusTmp":${tmpDir} \
        ${DOCKER_REGISTRY}/${netLocationService}:${netLocationDockerTag} \
        $dockerCmd
}

function start() {
    dockerCmd="/src/startNpm.sh ${COREOS_PRIVATE_IPV4} $instance"

    startDocker
}

function startDockerBash() {
    dockerCmd="/bin/bash $*"

    interactive="-it"

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

    docker rm -f ${containerName}

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

    docker kill -s KILL ${netlocationService}_$instance
}

if test "$1" == "-d"
then
    set -x
    shift 1
fi

functionName=$1
shift 1

instance=$1
containerName=${netLocationDockerTag}_$instance 

setup

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi

return 2>/dev/null || echo $usage && exit 1

