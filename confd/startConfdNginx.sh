#!/bin/bash

instance=1

function setup() {
    set -a
    . /etc/environment

    nginxDir=/opt/nginx
    nginxConfFile=$nginxDir/nginx.conf
    nginxPidFile=$nginxDir/nginx.pid

    shareDir="/home/core/share"
    if test -d "$shareDir"
    then
        nginxCoreosDir="$shareDir/nginx"
        nginxCoreosConfFile=$nginxCoreosDir/nginx.conf
        nginxCoreosPidFile=$nginxCoreosDir/nginx.pid
    fi

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

setup

cleanup

($shareDir/confd/startConfd.sh start $instance 2>&1 | tee -a $shareDir/monitor/tmp/startConfd.log) &

$shareDir/nginx/startNginx.sh start $instance 2>&1 | tee -a $shareDir/monitor/tmp/startNginx.log 
