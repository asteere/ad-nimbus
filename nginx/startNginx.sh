#! /bin/bash

set -x 


nginxDir=/opt/nginx
nginxConfFile=$nginxDir/nginx.conf
nginxPidFile=$nginxDir/nginx.pid

trap "{echo Sending stop to nginx; nginx -s stop }" TERM
trap "{echo Sending quit to nginx; nginx -s quit }" QUIT
trap "{echo Sending reload to nginx; nginx -s reload }" HUP
trap "{echo Sending reopen to nginx; nginx -s reopen }" USR1

for attempts in {1..60}
do
    if test -f "$nginxConfFile"
    then
        nginx -c "$nginxConfFile"
        break
    fi

    echo Sleep 10 and see if confd has come up and created $nginxConfFile
    ls -l $nginxConfFile
    sleep 10
done

