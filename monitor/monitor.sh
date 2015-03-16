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
    hostCpuAverage=`ssh -oStrictHostKeyChecking=no $host /home/core/share/monitor/calcHostCpuAverage.sh <<%END
yes
%END`

    echo $host hostCpuAverage=$hostCpuAverage
    numInstances=`fleetctl list-unit-files | grep $netLocationService | wc -l`
    if test "$hostCpuAverage" -gt 70 
    then
        nextInstance=$((numInstances+1))
        (cd ~/share/$netLocationService; fleetctl start ${netLocationService}@${nextInstance}.service)
        return
    fi

    if test "$hostCpuAverage" -lt 10 
    then
        # TODO: kill the instance doing the least work
        (cd ~/share/$netLocationService; fleetctl stop ${netLocationService}@${numInstances}.service) 
        return
    fi
}

function setup() {
    listOfCoreOs=`etctree 2> /dev/null | grep -e ".*=.*:" | sed '-e s/.*\/\(.*\)=\(.*\)/\1 \2/'`
    listOfIpAddrs=`echo $listOfCoreOs | sed -e 's/.* //' -e 's/:.*//'`
    listOfIpAddrsAndPorts=`echo $listOfCoreOs | sed 's/.* //'`

    echo listOfCoreOs
    echo $listOfCoreOs
    echo 

    echo listOfIpAddres
    echo $listOfIpAddres
    echo 

    echo listOfIpAddresAndPorts
    echo $listOfIpAddresAndPorts
    echo 

}

function forAllNetLocationCoreOs() {
    setup
    for i in $listOfIpAddrs
    do
        checkCpuUsage $i
    done
}

function checkResponseTime() {
    curl -f ${1}; 
}

if test "$1" == "start"
then
    while true; 
    do 
        forAllNetLocationCoreOs
        sleep 3 
    done
    exit 0
fi

if test "$1" == "stop"
then
    pkill monitor.sh
fi

