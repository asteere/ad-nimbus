#! /bin/bash

. /home/core/share/adNimbusEnvironment

set -x

export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$adNimbusDir/s3fs/lib64"
PATH=$PATH:"$adNimbusDir/s3fs"
/home/core/share/s3fs/s3fs -o passwd_file=/root/.passwd-3fs -o use_cache=/tmp/s3fs_cache ad-nimbus-bucket /tmp/s3fs_mnt

