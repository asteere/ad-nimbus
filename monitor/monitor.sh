#!/bin/bash 

# Provide access to the variables that the services use

export curlOptions='-s -L'

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

function runCurlGet() {
    url=$1
    curl $curlOptions -X GET http://$consulIpAddr:$consulHttpPort"${url}"?pretty
}

function runCurlPut() {
    useIpAddr=$consulIpAddr
    if test "$1" != ""
    then
        useIpAddr=$1
    fi

    url=$2
    dataFileArg=""
    if test "$3" != ""
    then
        headers='-H "Content-Type: application/json"'
        dataFileArg="-d $3"
    fi

    curl $curlOptions $headers $dataFileArg "http://$useIpAddr:$consulHttpPort${url}?pretty"
}

function registerService() {
    service=$1
    instance=$2
    serviceIpAddr=$3
    port=$4

    dataFile=`createServiceJsonFile $service $instance $serviceIpAddr $port`

    runCurlPut $serviceIpAddr "/v1/agent/service/register" "@$dataFile"
}

function createServiceId() {
    service=$1
    instance=$2
    serviceIpAddr=$3

    echo "$service@${instance}.service_$serviceIpAddr"
}

function createServiceJsonFile() {
    service=$1
    instance=$2
    serviceIpAddr=$3
    port=$4

    serviceId="`createServiceId $service $instance $serviceIpAddr`"

    # Use canned IP address so that all the fields are returned
    url="http://$serviceIpAddr:$port?ipAddress=198.243.23.131"

    jsonFile=/tmp/$service$instance.json

    echo '{
        "ID": "'$serviceId'",
        "Name": "'$service'",
        "Tags": [
            "'$service'",
            "v1"
        ],
        "Address": "'$serviceIpAddr'",
        "Port": '$port',
        "Checks": [
            {
                "Id": "'$serviceId'_http",
                "Name": "HTTP Response Time",
                "Notes": "'$serviceId'_http",
                "Http": "'$url'",
                "Interval": "10s",
                "Timeout": "5s"
            },
            {
                "Id": "'${serviceId}'_cpu-util",
                "Name": "CPU utilization",
                "Notes": "'${serviceId}'_cpu-util",
                "Script": "'$monitorDir'/checkCpu.sh '$serviceId' 2>&1 > '$monitorDir'/tmp/checkCpu.log",
                "Interval": "10s"
            }
        ]
    }' > $jsonFile

    echo $jsonFile

    #rm -f $jsonFile
}

function registerNetLocationService() {
    instance=$1
    serviceIpAddr=$2
    port=$netLocationGuestOsPort

    registerService netlocation $instance $serviceIpAddr $port
}

function registerNginxService() {
    instance=$1
    serviceIpAddr=$2
    port=$nginxGuestOsPort

    registerService nginx $instance $serviceIpAddr $port
}

function unregisterService() {
    service=$1
    instance=$2
    serviceIpAddr=$3

    if test "$1" == "" -o "$2" == "" -o "$3" == ""
    then 
        echo Usage: unregisterService '[nginx | netlocation] fleetctl_instance ipAddrOfService'
        return
    fi

    serviceId="`createServiceId $service $instance $serviceIpAddr`"

    runCurlPut $serviceIpAddr /v1/agent/service/deregister/$serviceId
}

function unregisterNetLocationService() {
    instance=$1
    serviceIpAddr=$2

    unregisterService $netLocationService $instance $serviceIpAddr
}

function unregisterNginxService() {
    instance=$1
    serviceIpAddr=$2

    unregisterService $nginxService $instance $serviceIpAddr
}


# From: https://www.consul.io/docs/agent/http/health.html
function getHealthOfNode() {
    node=$1

    # Returns the health info of a node
    runCurlGet /v1/health/node/$node
}

function getChecksForService() {
    service=$1

    # Returns the checks of a service
    runCurlGet /v1/health/checks/$service
}

function getNodesRunningService() {
    service=$1

    # Returns the nodes and health info of a service
    runCurlGet /v1/health/service/$service
}

function getStateOfService() {
    # Returns the checks in a given state: any, unknown, passing, warning, or critical
    state=$1
    runCurlGet /v1/health/state/$state
}

function getConsulLeader() {
    runCurlGet /v1/status/leader
}

function getConsulPeers() {
    runCurlGet /v1/status/peers
}

function getConsulNodes() {
    runCurlGet /v1/catalog/nodes
}

function getANodesServices() {
    node=$1

    runCurlGet /v1/catalog/node/$node
}

function getDataCenters() {
    runCurlGet /v1/catalog/datacenters
}

function getNodesInService() {
    service=$1

    runCurlGet /v1/catalog/service/$service
}

function getServicesInDataCenter() {
    runCurlGet /v1/catalog/services
}

function getChecksForService() {
    service=$1

    runCurlGet  /v1/health/checks/$service
}

function stopService() {
    serviceId=$1
    service=`echo $serviceId | sed 's/_.*//'`

    echo Stopping $service
    fleetctl stop $service
}

function startService() {
    serviceId=$1
    service=`echo $serviceId | sed -e 's/@.*//'`

    instance=`fleetctl list-units -fields=unit | grep $service | sed -e 's/.*@//' -e 's/.service//' | sort -n | tail -1`
    instance=$((++instance))

    cd /home/core/share/$service

    fleetCtlUnit=$service@${instance}.service
    echo Starting $fleetCtlUnit
    fleetctl start $fleetCtlUnit
}

declare -A criticalFailures

function handleCriticalHealthChecks() {
    currentlyFailedServices=`getStateOfService critical | \
            # User ServiceID as consul requires that to be unique
            awk '/ServiceID/ {gsub("\"", "", $NF); gsub(",", "", $NF); print $NF}' | \
            sort -u`

    # Go through the list of currently failed services
    #   If a service in the currently failed services is not in previously failed services, add it and set count to 0
    # Go through the list of previously failed services
    #   If the previously failed service is in the list of currently failed servies, increment
    #   If the previously failed service is NOT in the list of currently failed servies, decrement
    previouslyFailedServices=${!criticalFailures[@]}
    for svcIndex in $currentlyFailedServices
    do
        #echo Service :$svcIndex:
        count=${criticalFailures[$svcIndex]}
        
        if [[ $count == "" ]] 
        then
            echo Service $svcIndex not previously seen
            criticalFailures[$svcIndex]=0
        fi
    done

    dataCenterNetLocationFailures=0

    for svcIndex in "${!criticalFailures[@]}"
    do 
        serviceType=`echo $svcIndex | sed 's/@.*//'`

        #echo $svcIndex:${criticalFailures[$svcIndex]}
        count=${criticalFailures[$svcIndex]}
        
        if [[ $currentlyFailedServices == *$svcIndex* ]] 
        then
            echo Increment $svcIndex
            criticalFailures[$svcIndex]=$((++count))
            numNetLocationInstances=`getNumberServices $serviceType`
            if test "${criticalFailures[$svcIndex]}" -gt "$netlocationHighWaterMark" -a \
                "$numNetLocationInstances" -lt "$maxNumInstances"
            then
                startService $svcIndex

                # Reset the counters to let it run awhile and see if the problem clears up
                unset criticalFailures[$svcIndex]
            fi
        else
            if [[ "$count" -le 1 ]] 
            then
                echo Remove $svcIndex criticality count
                unset criticalFailures[$svcIndex]
                if test "$numNetLocationInstances" -gt "$minNumInstances"
                then
                    stopService $svcIndex
                fi
            else
                echo Decrement $svcIndex criticality count
                criticalFailures[$svcIndex]=$((--count))
            fi
        fi

        # Count the number of netlocation services that have failures.
        if [[ "$netLocationService" == "$serviceType" ]] 
        then
            echo Increment number of net location service failures
            dataCenterNetLocationFailures=$((dataCenterNetLocationFailures + 1))
        fi
    done

    serviceType=netlocation
    numNetLocationInstances=`getNumberServices $serviceType`
    echo Number of $serviceType services: $numNetLocationInstances
    echo Number of $serviceType errors in datacenter: $dataCenterNetLocationFailures
}

function getNumberServices() {
    fleetctl list-units -fields=unit | grep $1 | wc -l
}

function foo() {
    # Constants
    netLocationLowWaterMark=3

    # If the count is greater than high water mark and less than high water mark, start another netlocation
    # If the count is less than the low water mark and the num_instances is greater than minNumInstances, stop one

    if test $dataCenterNetLocationFailures -le $netLocationHighWaterMark -a $numNetLocationInstances -lt $maxNumInstances
    then
        startService ${netLocationService}
    fi

    if test $dataCenterNetLocationFailures -le $netLocationLowWaterMark 
    then
        stopService ${netLocationService}
    fi
}

function dumpCriticalFailures() {
    if [[ "${!criticalFailures[@]}" == "" ]]
    then
        return
    fi

    echo Status on CriticalFailures:
    for svcIndex in "${!criticalFailures[@]}"
    do
        echo 'criticalFailures['$svcIndex']='${criticalFailures[$svcIndex]}
    done
}

function runOtherChecks() {
    dataCenters=`getDataCenters`
    echo Known datacenters: $dataCenters

    echo
    echo List Services running in datacenter
    getServicesInDataCenter

    # Check that there is a raft leader
    echo
    echo
    leader=`getConsulLeader`
    echo Leader: $leader

    # Check that there are peers
    echo
    peers=`getConsulPeers`
    echo Peers: $peers

    # Lists nodes in a given DC. Should equal numInstances
    echo
    echo Nodes: 
    getConsulNodes

    # Lists the services provided by a node 
    echo
    echo
    nodes=`getConsulNodes | awk '/Node/ {gsub("\"", "", $NF); gsub(",", "", $NF); print $NF}'`
    for node in $nodes
    do
        servicesOnNode=`getANodesServices $node`
        if test "$servicesOnNode" == ""
        then
            echo Node $node is not running any services
        else
            echo Node $node is running the following services:
            getANodesServices $node
            echo
        fi
    done

    echo 
    echo List nodes running a given service
    for svc in nginx netlocation
    do
        echo $svc: 
        getNodesInService $svc
        echo
    done

    echo
    echo List checks for a given service
    for svc in nginx netlocation
    do
        echo $svc
        getChecksForService $svc
        echo
    done
}

function runChecks() {
    if test "$runAll" == "true"
    then
        runOtherChecks
    fi

    echo
    for state in warning critical 
    do
        badNodes=`getStateOfService $state | awk '/ServiceID/ {gsub("\"", "", $NF); gsub(",", "", $NF); print $NF}'`
        if test "$badNodes" == ""
        then
            echo No services are in $state state
        else
            echo Services that are in $state state: 
            getStateOfService $state
            if [[ $state == "critical" ]]
            then
                echo
                handleCriticalHealthChecks
            fi
            echo
        fi
    done

    dumpCriticalFailures
}

# TODO: When a check gets set should we set the consulIpAddr to that address so it runs local
export consulIpAddr=172.17.8.101

runAll=false

while getopts "ad" opt; do
  case "$opt" in
    a)
        runAll=true
        ;;
    d)
      set -x;
      ;;
  esac
done
shift $((OPTIND-1))

if test "$1" == "start"
then
    while true; 
    do 
        # Run setup each time to allow dynamic changes of controlling variables
        setup

        runChecks

        sleep $monitorRunChecksInterval 
    done
    exit 0
fi

if test "$1" == "stop"
then
    pkill monitor.sh
    return 2>/dev/null || exit 0
fi

setup

# TODO: Do we need to expand this beyond register*Service and unregisterService?
if [[ `type -t $1` == "function" ]]
then
    ${1} $2 $3
    exit 0
fi

return 2>/dev/null || echo Usage: `basename $0` '[start|stop]' && exit 1

