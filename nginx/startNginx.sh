#! /bin/bash

nginxDir=/opt/nginx
nginxConfFile=$nginxDir/nginx.conf
nginxPidFile=$nginxDir/nginx.pid

function sendSignal() {
    echo Sending $1 to nginx
    nginx -s $1 

}

trap 'sendSignal stop' TERM
trap 'sendSignal quit' QUIT
trap 'sendSignal reload' HUP
trap 'sendSignal reopen' USR1

while true
do
    echo $attempts
    if test -f "$nginxConfFile"
    then
        nginx -c "$nginxConfFile"
        break
    fi

    interval=5
    echo Sleep $interval and see if confd has come up and created $nginxConfFile
    sleep $interval
done

