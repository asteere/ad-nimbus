#!/bin/bash 

# Provide access to the variables that the services use
set -a
. /etc/environment
. /home/core/share/adNimbusEnvironment
set +a

. /home/core/share/.coreosProfile

function startAnotherService() {
    echo startAnotherService
}

function selectAndStopAService() {
    echo selectAndStopAService
}

function checkCpuUsage() {
    host=$1

    hostCpuAverage=`ssh -oStrictHostKeyChecking=no $host /home/core/share/monitor/calcHostCpuAverage.sh`

    echo $host hostCpuAverage=$hostCpuAverage
}

function startStopServiceBasedOnCpuUsage() {
    clusterAvgCpuUsage=$1
    numInCluster=$2

    numInstances=`fleetctl list-unit-files | grep $netLocationService | wc -l`

    if test $numInstances != $numInCluster
    then
        echo Error: fleetctl reports $numInstances of $netlocationService. etcdctl reports $numInCluster IP addresses"
        echo fleetctl:
        fluf

        echo etcdctl:
        etctree

        echo Attempt to continue, results may be confusing
    fi
 
    if test "$hostCpuAverage" -gt 70 -o -f /home/core/share/addService
    then
        nextInstance=$((numInstances+1))
        echo Start new service
        (cd ~/share/$netLocationService; fleetctl start ${netLocationService}@${nextInstance}.service)
        return
    fi

    if test "$hostCpuAverage" -lt 10 && $numInstances -gt 2 -o -f /home/core/share/removeService
    then
        # TODO: kill the instance doing the least work
        echo Shutting down $host
        (cd ~/share/$netLocationService; fleetctl stop ${netLocationService}@${numInstances}.service) 
        return
    fi
}

function setup() {
    listOfCoreOs=`etctree 2> /dev/null | grep -e ".*=.*:" | sed '-e s/.*\/\(.*\)=\(.*\)/\1 \2/'`
    listOfIpAddress=`echo $listOfCoreOs | sed -e 's/core-[0-9][0-9] //g' -e 's/:[0-9]*//g'`
    listOfIpAddressAndPorts=`echo $listOfCoreOs | sed 's/core-[0-9][0-9] //g'`
}

function checkAllNetLocationCoreOs() {
    setup

    sumCpuUsage=0
    numInCluster=0
    for i in $listOfIpAddress
    do
        cpuUsage=`checkCpuUsage $i`
        sumCpuUsage=`eval $sumCpuUsage + $cpuUsage`
        numInCluster=`eval $numInCluster + 1`
    done

    clusterAvgCpuUsage=`eval $sumCpuUsage / $numInCluster`

    startStopServiceBasedOnCpuUsage $clusterAvgCpuUsage $numInCluster
}

function checkResponseTime() {
    curl -f ${1}; 
}

if test "$1" == "start"
then
    while true; 
    do 
        checkAllNetLocationCoreOs
        sleep 3 
    done
    exit 0
fi

if test "$1" == "stop"
then
    pkill monitor.sh
fi

