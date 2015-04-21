#! /bin/bash

set -x 

nginxDir=/opt/nginx
nginxConfFile=${nginxDir}/nginx.conf

for attempts in {1..30}
do
    if test -f "${nginxConfFile}"
    then
        nginx -c "${nginxConfFile}"
        break
    fi

    echo Sleep 10 and see if confd has come up and written the file
    sleep 10
done

