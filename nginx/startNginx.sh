#! /bin/bash

set -e

. /etc/environment
. /home/core/share/adNimbusEnvironment

set +e

nginxConfFile=/${nginxDir}/nginx.conf

for attempts in {1..30}
do
    if test -f ${nginxConfFile}
    then
        ${nginxDir}/${nginxService} -c ${nginxDir}/nginx.conf
        return
    fi

    echo Sleep 10 and see if confd has come up and written the file
    sleep 10

done

