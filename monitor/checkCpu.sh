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

pCpu=`ps -eo pcpu,comm | grep "$processName" | grep -v -e docker -e grep | awk '{printf("%.0f\n", $1);}'`
set +x

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

