#!/bin/bash

echo '=========================' `basename $0` args:$*: '=========================='

function setup() {
    set -a
    . /etc/environment

    nginxDir=/opt/nginx
    nginxConfFile="$nginxDir/nginx.conf"

    webContentDir=/opt/WebContent

    . /home/core/ad-nimbus/adNimbusEnvironment

    nginxCoreosDir="$adNimbusDir/nginx"
    nginxCoreosConfFile="$nginxCoreosDir/nginx.conf"
    nginxCoreosCidFile="$adNimbusTmp/nginx.cid"
    nginxCoreosIpAddrFile="$adNimbusTmp/nginx.ipaddr"

    webContentCoreosDir="/home/core/WebContent"
    
    dockerCmd="nginx -c $nginxConfFile"

    svc=${nginxService}
    containerName=${svc}_$instance

    set +a

    trap 'sendSignal stop' TERM
    trap 'sendSignal quit' QUIT
    trap 'sendSignal reload' HUP
    trap 'sendSignal reopen' USR1
}

function loadContainers() {
    docker rm -f ${containerName} > /dev/null 2>&1
    $adNimbusDir/adnimbus_registry/startAdNimbusRegistry.sh startPre $svc

    docker ps -a
}

function startDocker() {
    loadContainers

    echo ${COREOS_PRIVATE_IPV4} > "$nginxCoreosIpAddrFile"

    if test -d "$webContentCoreosDir"
    then
        webContentVolArg="--volume=$webContentCoreosDir:$webContentDir"
    fi

    /usr/bin/docker run \
        --name=$containerName $interactiveArg $cidFileArg \
        --rm=true $webContentVolArg \
        --volume=/var/run/docker.sock:/var/run/docker.sock \
        --volume="$adNimbusDir"/${nginxService}:${nginxDir} \
        --volume="$adNimbusTmp":${tmpDir} \
        -p ${nginxGuestOsPort}:${nginxContainerPort} \
        ${DOCKER_USER}/${nginxService}:${nginxDockerTag} \
        $dockerCmd
}

function startDockerBash() {
    dockerCmd="/bin/bash $*"

    interactiveArg="-it"

    startDocker
}

function runCmd() {
    cmd=$1

    /usr/bin/docker exec $containerName $nginxService -s $cmd -c $nginxConfFile
}

function reload() {
    runCmd reload
}

# TODO: Is this needed?
function sendSignal() {
    echo Sending $1 to $nginxService

    runCmd $1
}

function waitForNginxConf() {
    while true
    do
        if test -f "$nginxCoreosConfFile"
        then
            break
        fi

        interval=3
        echo `date`: Sleep $interval and see if confd has come up and created $nginxCoreosConfFile
        sleep $interval
    done
    ls -l $nginxCoreosConfFile 
}

function start() {
    waitForNginxConf

    # Allow other containers/services to communicate with niginx via the PID
    cidFileArg="--cidfile=${nginxCoreosCidFile}"

    startDocker
}

function stop() {
    runCmd stop

    if test "$instance" == ""
    then
        instance=$1
    fi

    docker kill -s KILL $containerName
}

#set -x 

while getopts "ad" opt; do
  case "$opt" in
    d)
      set -x;
      ;;
  esac
done
shift $((OPTIND-1))

functionName=$1
shift 1

instance=$1
shift 1
if test "$instance" == ""
then
    instance=1
fi

setup 

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi

return 2>/dev/null || echo Usage: `basename $0` 'functionName instance functionArguments' && exit 1


