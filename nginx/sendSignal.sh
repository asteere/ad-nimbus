#!/bin/bash

set -x

# Find the nginx container id
nginxCidFile=/opt/nginx/nginx.cid
if test ! -f "$nginxCidFile"
then
    echo Warning: No $nginxCidFile found, has nginx been started?
    exit 
fi

nginxId=`cat $nginxCidFile`

# Send the signal to the nginx container id
echo -e 'POST /containers/'$nginxId'/kill?signal=SIGHUP HTTP/1.0\r\n' | nc -U /var/run/docker.sock
