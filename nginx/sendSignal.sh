#!/bin/bash

set -x

function findMachineRunningService() {
    service=$1

    fleetctl list-units -fields=unit,machine --no-legend | grep $service | awk '{print $2}'
}

# Find the nginx container id
if test -d /opt/nginx
then
    nginxDir=/opt/nginx
    tmpDir=/opt/tmp
else
    nginxDir=/home/core/share/nginx
    tmpDir=/home/core/share/tmp
fi
nginxCidFile="$tmpDir"/nginx.cid

if test ! -f "$nginxCidFile"
then
    echo Warning: No $nginxCidFile found, has nginx been started?
    exit 
fi

nginxId=`cat $nginxCidFile`

# Send the signal to the nginx container id
echo -e 'POST /containers/'$nginxId'/kill?signal=SIGHUP HTTP/1.0\r\n' | nc -U /var/run/docker.sock

grep 'server 1' ${nginxDir}/nginx.conf
