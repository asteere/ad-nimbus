#! /bin/bash

# Allow functions to be watched
# Works:
#   Functions sourced at start of each script (.hostProfile) can be watched

if test "$1" == "-d"
then
    set -x
    shift 1
fi

set -a

if test "`uname -s`" == "Darwin"
then
    . "$adNimbusDir"/.hostProfile
else
    . "$adNimbusDir"/.coreosProfile
fi

export -f `grep '^function' "$adNimbusDir"/.awsProfile "$adNimbusDir"/.hostProfile \
    "$adNimbusDir"/.coreosProfile "$adNimbusDir"/.sharedFunctions | \
    sed 's/.*ion \(.*\)(.*/\1/'` 2> /dev/null

set +a

cmd=`basename $0`

Usage="$cmd watchArguments scriptFunctionAlias arguments"

#echo $*

watch $*
