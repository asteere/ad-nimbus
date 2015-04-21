#! /bin/bash

set -x

(cd /src; npm install)

node /src/index.js
