#!/bin/bash

echo `basename $0` args:$*:

set -x

function setup() {
    set -a
    . /etc/environment

    nginxDir=/opt/nginx
    nginxConfFile="$nginxDir/nginx.conf"

    if test -d "/home/core/share"
    then
        nginxCoreosDir="/home/core/share/nginx"
        nginxCoreosConfFile="$nginxCoreosDir/nginx.conf"
        nginxCoreosCidFile="$nginxCoreosDir/nginx.cid"
        nginxCoreosIpAddrFile="$nginxCoreosDir/nginx.ipaddr"
    fi

    set +a

    trap 'sendSignal stop' TERM
    trap 'sendSignal quit' QUIT
    trap 'sendSignal reload' HUP
    trap 'sendSignal reopen' USR1
}

function startDocker() {
    rm -f "$nginxCoreosCidFile" "$nginxCoreosIpAddrFile"

    echo ${COREOS_PUBLIC_IPV4} > "$nginxCoreosIpAddrFile"

    /usr/bin/docker run \
        --name=${nginxDockerTag}_${instance} \
        --cidfile=${nginxCoreosCidFile} \
        --rm=true \
        --volume=/var/run/docker.sock:/var/run/docker.sock \
        --volume=/home/core/share/${nginxService}:${nginxDir} \
        -p ${nginxGuestOsPort}:${nginxContainerPort} \
        ${DOCKER_REGISTRY}/${nginxService}:${nginxDockerTag} \
        nginx -c "$nginxConfFile"
}

function runCmd() {
    cmd=$1
    /usr/bin/docker exec nginx_1 nginx -s $cmd -c $nginxConfFile
}

function reload() {
    runCmd reload
}

# TODO: Is this needed?
function sendSignal() {
    echo Sending $1 to nginx
    runCmd stop

    # TODO: This may be overkill
    docker kill -s $1 
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

    startDocker
}

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

setup 

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi

return 2>/dev/null || echo Usage: `basename $0` 'functionName instance functionArguments' && exit 1


