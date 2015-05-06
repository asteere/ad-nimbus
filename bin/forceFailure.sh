#! /bin/sh


# If the arg is clear remove the files
# If the arg is start see what type of failure they want internal (cpu-util)  or external (http)

function setup() {
    trap 'cleanup TERM' TERM
    trap 'cleanup INT' INT 
    trap 'cleanup QUIT' QUIT 
    trap 'cleanup HUP' HUP
    trap 'cleanup USR1' USR1

    set -a
        
    for envFile in /etc/environment /home/core/share/adNimbusEnvironment 
    do  
        if test ! -f "$envFile"
        then
            echo Error: Unable to find envFile $envFile
            exit 1
        fi
        . "$envFile"
    done

    service=netlocation

    # The CPU Util test is considered an internal test
    internalDir="$AD_NIMBUS_DIR"/monitor/tmp

    # The HTTP test is considered an external test
    externalDir="$AD_NIMBUS_DIR"/$service/src/tmp

    set +a
}

function setFailure() {
    # Only use one service
    svcToFail=`fleetctl list-units -fields=unit,machine --no-legend | \
        grep $service | \
        sed 's/\(.*service\).*\/\(.*\).*/\1_\2/' | head -1`

    if test "$healthCheckType" == "external"
    then
        cfgFile=$externalDir/${svcToFail}.cfg
    else
        cfgFile=$internalDir/$svcToFail.cfg
    fi

    echo Create $healthCheckType failure for service $svcToFail 
    echo 30 > $cfgFile

    listFailure
}

function clearFailure() {
    echo Clearing all health check config files
    rm -f $internalDir/*.cfg
    rm -f $externalDir/*.cfg

    listFailure
}

function listFailure() {
    echo Listing all health check config files
    ls -l $internalDir/*.cfg
    ls -l $externalDir/*.cfg
}

function usage() {
    echo Usage: `basename $0` 'COMMAND [arg...]'
    echo '  'command - set, show or clear. set is the default. 
    echo '      'set [type] - create a health check if a netlocation service is running
    echo '          'type - internal, external. internal is the default
    echo '      'clear - clears all health checks, no arguments
    echo '      'list - lists all health checks, no arguments
}

if test "$1" == "-d"
then
    set -x
    shift 1
fi

setup

case "$#" in 
0)
    command=setFailure
    healthCheckType=internal
    ;;
1)
    command=${1}Failure
    healthCheckType=internal
    shift 1
    ;;
2)
    command=${1}Failure
    healthCheckType=$2
    ;;
*)
    usage
    exit 1
    ;;
esac

case "$healthCheckType" in 
internal|cpu)
    healthCheckType=internal
    ;;
external|http)
    healthCheckType=external
    ;;
*)
    usage
    exit 1
    ;;
esac

if [[ `type -t $command` == "function" ]]
then
    ${command}
    exit 0
fi

return 2>/dev/null || usage && exit 1

