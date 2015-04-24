#! /bin/bash

set -x

(cd /src; npm install)

node /src/index_consul.js $1
