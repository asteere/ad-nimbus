#!/bin/bash

echo `basename $0` args:$*:

functionName=$1
instance=$2

function setup() {
    set -a
    . /etc/environment
    . /home/core/ad-nimbus/adNimbusEnvironment

    set +a

    trap 'sendSignal stop' TERM
    trap 'sendSignal quit' QUIT
    trap 'sendSignal reload' HUP
    trap 'sendSignal reopen' USR1
}

# TODO: Is this needed?
function sendSignal() {
    echo Sending $1 to nginx
    docker kill -s $1 
}

function cleanup() {
    origDir=`pwd`

    # The first time confd & nginx runs there will be no nginx.conf. Test this use case when starting all services
    cd "$adNimbusTmp"
    rm -f startConfd.log startNginx.log nginx.error.log nginx.access.log nginx.cid
    
    rm -f "$adNimbusDir/nginx/nginx.conf"

    cd "$origDir"
}

function start() {
    cleanup

    "$adNimbusDir"/confd/startConfd.sh start $instance 2>&1 | tee "$adNimbusTmp"/startConfd.log &

    "$adNimbusDir"/nginx/startNginx.sh start $instance 2>&1 | tee "$adNimbusTmp"/startNginx.log 
}

function stop() {
    "$adNimbusDir"/confd/startConfd.sh stop $instance 2>&1 | tee -a "$adNimbusTmp"/startConfd.log 

    "$adNimbusDir"/nginx/startNginx.sh stop $instance 2>&1 | tee -a "$adNimbusTmp"/startNginx.log 
}

setup

set -x

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi
