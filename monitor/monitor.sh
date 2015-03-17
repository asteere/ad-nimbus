#!/bin/bash 

# Provide access to the variables that the services use
set -a
. /etc/environment
. /home/core/share/adNimbusEnvironment
set +a
set -x
# TODO: BEGIN: Remove when we don't need the aliases and function to help development
function etctree() { 
    # TODO: get the key from adNimbusEnvironment, shouldn't be hardcoded
    for key in `etcdctl ls -recursive /raptor/netlocation`
    do
        echo -n $key=
        etcdctl get $key
    done
}

# TODO: END: Remove ...

function checkCpuUsage() {
    host=$1

    hostCpuAverage=`ssh -oStrictHostKeyChecking=no $host /home/core/share/monitor/calcHostCpuAverage.sh`
    if [[ $hostCpuAverage == "" ]]
    then
        hostCpuAverage=0
    fi
    echo $host hostCpuAverage=$hostCpuAverage
}

function startStopServiceBasedOnCpuUsage() {
    clusterAvgCpuUsage=$1
    numInCluster=$2

    numInstancesLaunched=`fleetctl list-unit-files | grep $netLocationService | grep 'launched *launched' | wc -l`

    if test $numInstancesLaunched != $numInCluster
    then
        set +x
        echo Error: fleetctl reports $numInstancesLaunched of $netLocationService launched. etcdctl reports $numInCluster IP addresses
        echo fleetctl:
        fleetctl list-unit-files

        echo etcdctl:
        etctree

        echo Attempt to continue, results may be confusing
        set -x
    fi
 
    if [[ "$hostCpuAverage" -gt 70 && "$numInstancesLaunched" -lt "$maxNetLocationServices" ]] || \
        [[ -f /home/core/share/addService ]]
    then
        nextInstance=$((numInCluster+1))
        echo Start new service
        (cd /home/core/share/$netLocationService; fleetctl start ${netLocationService}@${nextInstance}.service)
        return
    fi

    if [[ "$hostCpuAverage" -lt 10 && "$numInstancesLaunched" -gt "$minNetLocationServices" ]] || \
        [[ -f /home/core/share/removeService ]]
    then
        # TODO: kill the instance doing the least work
        # TODO: Figure out the service number to shutdown
        echo Shutting down $host
        (cd /home/core/share/$netLocationService; fleetctl stop ${netLocationService}@${numInCluster}.service) 
        return
    fi
}

function setup() {

    # TODO: remove once debug statement not needed
    etctree

    listOfCoreOs=`etctree 2> /dev/null | grep -e ".*=.*:" | sed '-e s/.*\/\(.*\)=\(.*\)/\1 \2/'`
    listOfIpAddress=`echo $listOfCoreOs | sed -e 's/core-[0-9][0-9] //g' -e 's/:[0-9]*//g'`
    listOfIpAddressAndPorts=`echo $listOfCoreOs | sed 's/core-[0-9][0-9] //g'`
}

function checkAllNetLocationCoreOs() {
    setup

    if [[ $listOfIpAddress == "" ]]
    then
        return
    fi

    sumCpuUsage=0
    numInCluster=0
    for ipAddr in $listOfIpAddress
    do
        checkCpuUsage $ipAddr
        sumCpuUsage=$((sumCpuUsage + hostCpuAverage))
        numInCluster=$((numInCluster + 1))
    done

    clusterAvgCpuUsage=$((sumCpuUsage / numInCluster))

    startStopServiceBasedOnCpuUsage $clusterAvgCpuUsage $numInCluster
}

function checkResponseTime() {
    curl -f ${1}; 
}

function setupSsh() {
    # Setup fleetctl status
    if test "$SSH_AUTH_SOCK" == ""
    then
        eval $(ssh-agent)
    fi

    ssh-add -L | grep insecure_private_key 2>&1 > /dev/null
    if test ! $? == 0
    then
        ssh-add /home/core/share/insecure_private_key
    fi
}

if test "$1" == "start"
then
    setupSsh

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
    exit 0
fi

echo Usage: `basename $0` '[start|stop]'
exit 1

