#!/bin/bash

instance=1

function cleanup() {
    rm -f monitor/tmp/startConfd.log monitor/tmp/startNginx.log

    # The first time confd & nginx runs there will be no nginx.conf. Test this use case when starting all services
    (cd /home/core/share/nginx; rm -f nginx.conf nginx.error.log nginx.access.log nginx.cid)
}

cleanup

/home/core/share/confd/startConfd.sh start $instance 2>&1 | tee -a monitor/tmp/startConfd.log &

/home/core/share/nginx/startNginx.sh start $instance 2>&1 | tee -a monitor/tmp/startNginx.log 
