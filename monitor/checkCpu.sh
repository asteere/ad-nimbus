#! /bin/sh

echo `date`: '===============================' $0 args:$* "==============="
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
    if test -d "/home/core/ad-nimbus/monitor"
    then
        monitorDir=/home/core/ad-nimbus/monitor
        tmpDir=/home/core/ad-nimbus/tmp
    else
        monitorDir=/opt/monitor
        tmpDir=/opt/tmp
    fi
}

function setup() {
    set -a

    updateMonitorDir

    . /etc/environment 
    . "${monitorDir}/monitorEnvironment"

    # reset this based on actual filesystem
    updateMonitorDir

    set +a
}

setup

serviceId=netlocation@1.service_172.17.8.101
if test "$1" != ""
then
    serviceId="$1"
fi

echo docker exec netlocation_1 ps -Ao pid,pcpu,args
docker exec netlocation_1 ps -Ao pid,pcpu,args

echo ps -Ao pid,pcpu,args
ps -Ao pid,pcpu,args

unset sudoCmd
if test "`which sudo`" != ""
then
    sudoCmd=sudo
fi

echo $sudoCmd ps -Ao pid,pcpu,args
$sudoCmd ps -Ao pid,pcpu,args

processName=$(echo $serviceId | sed 's/@.*//')
if [[ "$serviceId" == *"netlocation"* ]]
then
    processName='node'
fi

ipAddr=$(echo $serviceId | sed 's/.*_//')
echo Looking for processName:$processName ipAddr:$ipAddr

# TODO: consul health checks run in the consul container and can't see the netlocation container processes

processInfo=`ps -Aeo pcpu,comm,args | grep "$processName" | grep $ipAddr | grep -v -e docker -e grep -e /opt/consul/consul`
echo Process information: $processInfo

pCpu=$(echo $processInfo | awk '{printf("%.0f\n", $1);}')
echo Percent CPU for $processName is $pCpu

cpuCfgFile="${tmpDir}/internal/${serviceId}.cfg"
date
echo Looking for $cpuCfgFile
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

