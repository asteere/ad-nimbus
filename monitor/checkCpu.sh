#! /bin/sh

echo '==============================='
set -x 

# Consul script health check "constants"
exitSuccess=0
exitWarning=1
exitCritical=2

function calcOverallCpuPercent() {
    cpuPercent=`ps -eo pcpu,cmd | grep -v -e 'CPU CMD' | awk '{percentTotal+=$1;} END {printf("%.0f\n", percentTotal)}'`
}

function updateMonitorDir() {
    # Enable the script to be run from coreos and docker
    if test -d "/home/core/share/monitor"
    then
        monitorDir=/home/core/share/monitor
    else
        monitorDir=/opt/monitor
    fi
}

function setup() {
    set -a

    updateMonitorDir

    for envFile in /etc/environment "${monitorDir}/monitorEnvironment"
    do
        echo envFile:$envFile
        if test ! -f "$envFile"
        then
            echo Error: Unable to find envFile $envFile
            exit $exitCritical
        fi
        . "$envFile"
    done

    updateMonitorDir

    set +a
}

setup

serviceId=netlocation@1.service_172.17.8.101
if test "$1" != ""
then
    serviceId="$1"
fi

processName=$(echo $serviceId | sed 's/@.*//')
if [[ "$serviceId" == *"netlocation"* ]]
then
    processName=node
fi

ipAddr=$(echo $serviceId | sed 's/.*_//')
processInfo=`ps -eo pcpu,comm,args | grep "$processName" | grep $ipAddr | grep -v -e docker -e grep`
echo Process information: $processInfo

pCpu=$(echo $processInfo | awk '{printf("%.0f\n", $1);}')
echo Percent CPU for $processName is $pCpu

cpuCfgFile="${monitorDir}/tmp/${serviceId}.cfg"
date
echo Looking for $cpuCfgFile
#ls -l ${monitorDir}/tmp
if test -f "$cpuCfgFile"
then
    oldPCpu=$pCpu
    pCpu=`cat $cpuCfgFile`

    echo DemoOverride: $serviceId is now using $pCpu percent of the CPU. Was using $oldPCpu percent.
fi

if test "$pCpu" == ""
then
    echo Process $processName is not running on behalf of $serviceId, return critical
    exit $exitCritical
fi

echo $serviceId is using \"$pCpu\" percent of the CPU percentCpuSuccess=\"$percentCpuSuccess\" percentCpuWarning=\"$percentCpuWarning\"

if test "$pCpu" -lt "$percentCpuSuccess"
then
    echo No worries, return success
    exit $exitSuccess
fi

if test "$pCpu" -lt "$percentCpuWarning"
then
    echo A little worry, return warning
    exit $exitWarning
fi

echo Big worries, return critical
exit $exitCritical

