#! /bin/bash

set -a
if test -d "/home/core/share"
then
    . "$AD_NIMBUS_DIR"/.coreosProfile
else
    . "$AD_NIMBUS_DIR/".hostProfile
fi
set +a

cmd=`basename $0`

Usage="$cmd -n interval scriptFunctionAlias arguments"

set -x
echo $*
interval=2
if test "$1" == "-n"
then
    shift 1
    interval=$1
    shift 1
fi

if test "$cmd" == "mywatch.sh"
then
    typeset -f "$*"
    watch -n $interval $*
else
    typeset -f vs
    mywatch.sh watch -n $interval $*
fi
