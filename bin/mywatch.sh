#! /bin/bash

# Allow functions to be watched
# Works:
#   Functions sourced at start of each script (.hostProfile) can be watched
# TODO:
#   Export functions that haven't been to allow watch to find them.

#set -x

set -a

if test "`uname -s`" == "Darwin"
then
    . "$adNimbusDir"/.hostProfile
else
    . "$adNimbusDir"/.coreosProfile
fi
set +a

cmd=`basename $0`

Usage="$cmd watchArguments scriptFunctionAlias arguments"

#echo $*

watch $*
