#!/bin/bash

instance=1

/home/core/share/confd/startConfd.sh startDocker $instance &

/home/core/share/nginx/startNginx.sh start $instance
