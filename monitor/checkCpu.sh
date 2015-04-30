#! /bin/sh

function setup() {
    set -a

    for envFile in /etc/environment /home/core/share/adNimbusEnvironment /home/core/share/monitor/monitorEnvironment
    do
        if test -f "$envFile"
        then
            . "$envFile"
        fi
    done
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

set +x

# Enable the script to be run from coreos and docker
if test ! -d ${monitorDir}
then
    monitorDir=/home/core/share/monitor
fi

cpuCfgFile="${monitorDir}/tmp/${serviceId}.cfg"
date
echo Looking for $cpuCfgFile
ls -l ${monitorDir}/tmp
if test -f "$cpuCfgFile"
then
    oldPCpu=$pCpu
    pCpu=`cat $cpuCfgFile`

    echo DemoOverride: $serviceId is now using $pCpu percent of the CPU. Was using $oldPCpu percent.
fi

if test "$pCpu" == ""
then
    echo Process $processName is not running on behalf of $serviceId, return critical
    exit 2
fi

echo $serviceId is using $pCpu percent of the CPU

if test "$pCpu" -lt "$percentCpuSuccess"
then
    echo No worries, return success
    exit 0
fi

if test "$pCpu" -lt "$percentCpuWarning"
then
    echo A little worry, return warning
    exit 1
fi

echo Big worries, return critical
exit 2

