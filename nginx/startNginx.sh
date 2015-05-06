#! /bin/bash

set -x

function setup() {
    set -a
    . /etc/environment

    nginxDir=/opt/nginx
    nginxConfFile=$nginxDir/nginx.conf
    nginxPidFile=$nginxDir/nginx.pid

    if test -d "/home/core/share"
    then
        nginxCoreosDir="/home/core/share/nginx"
        nginxCoreosConfFile=$nginxCoreosDir/nginx.conf
        nginxCoreosPidFile=$nginxCoreosDir/nginx.pid
    fi

    set +a

    trap 'sendSignal stop' TERM
    trap 'sendSignal quit' QUIT
    trap 'sendSignal reload' HUP
    trap 'sendSignal reopen' USR1
}

function startDocker() {
    /usr/bin/docker run \
        --name=${nginxDockerTag}_${instance} \
        --cidfile=${nginxCoreosDir}/nginx.cid \
        --rm=true \
        --host=${COREOS_PUBLIC_IPV4}:2375 \
        --volume=/var/run/docker.sock:/var/run/docker.sock \
        --volume=/home/core/share/${nginxService}:${nginxDir} \
        -p ${COREOS_PUBLIC_IPV4}:${nginxGuestOsPort}:${nginxContainerPort} \
        ${DOCKER_REGISTRY}/${nginxService}:${nginxDockerTag} \
        nginx -c "$nginxConfFile"
}

# TODO: Is this needed?
function sendSignal() {
    echo Sending $1 to nginx
    docker kill -s $1 

}

function waitForNginxConf() {
    while true
    do
        if test -f "$nginxCoreosConfFile"
        then
            break
        fi

        interval=5
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


