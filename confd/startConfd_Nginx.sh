#!/bin/bash

echo `basename $0` args:$*:

functionName=$1
instance=$2

function setup() {
    set -a
    . /etc/environment

    shareDir="/home/core/share"

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
    rm -f monitor/tmp/startConfd.log monitor/tmp/startNginx.log

    # The first time confd & nginx runs there will be no nginx.conf. Test this use case when starting all services
    (cd $shareDir/nginx; rm -f nginx.conf nginx.error.log nginx.access.log nginx.cid)
}

set -x

setup

cleanup

$shareDir/confd/startConfd.sh start $instance 2>&1 | tee $shareDir/monitor/tmp/startConfd.log &

$shareDir/nginx/startNginx.sh start $instance 2>&1 | tee $shareDir/monitor/tmp/startNginx.log 
