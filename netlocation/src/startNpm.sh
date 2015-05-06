#! /bin/bash

set -x

(cd /src; npm install)

ipAddr=$1
instance=$2
node /src/index_consul.js $ipAddr $instance
