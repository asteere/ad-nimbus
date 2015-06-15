#! /bin/bash

# Allow functions to be watched
# Works:
#   Functions sourced at start of each script (.hostProfile) can be watched
# TODO:
#   Export functions that haven't been to allow watch to find them.
function createScript() {
    export -f $funcName
    watch $watchArgs $funcName $funcArgs
}

set -a
if test -d "/home/core/share"
then
    . "$adNimbusDir"/.coreosProfile
else
    . "$adNimbusDir/".hostProfile
fi
set +a

cmd=`basename $0`

Usage="$cmd watchArguments scriptFunctionAlias arguments"

#set -x
echo $*

watch $*
