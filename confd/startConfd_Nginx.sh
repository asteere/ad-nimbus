#!/bin/bash

echo `basename $0` args:$*:

functionName=$1
instance=$2

function setup() {
    set -a
    . /etc/environment
    . /home/core/share/adNimbusEnvironment

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
    cd "$adNimbusDir"/nginx; 
    rm -f nginx.conf nginx.error.log nginx.access.log nginx.cid

    cd "$adNimbusDir"/monitor/tmp/
    rm -f startConfd.log startNginx.log

    cd "$origDir"
}

set -x

setup

cleanup

"$adNimbusDir"/confd/startConfd.sh start $instance 2>&1 | tee "$adNimbusDir"/monitor/tmp/startConfd.log &

"$adNimbusDir"/nginx/startNginx.sh start $instance 2>&1 | tee "$adNimbusDir"/monitor/tmp/startNginx.log 
