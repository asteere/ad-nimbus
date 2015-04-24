#!/bin/bash 

# Provide access to the variables that the services use

export curlOptions='-s -L'

function setup() {
    set -a

    if test -f /etc/environment
    then
        . /etc/environment
    fi
    if test -f /home/core/share/adNimbusEnvironment
    then
        . /home/core/share/adNimbusEnvironment
    fi

    set +a
}

function runCurlGet() {
    url=$1
    curl $curlOptions -X GET http://$consulIpAddr:$consulHttpPort"${url}"?pretty
}

function runCurlPut() {
    url=$1
    dataFileArg=""
    if test "$2" != ""
    then
        headers='-H "Content-Type: application/json"'
        dataFileArg="-d $2"
    fi

    curl $curlOptions $headers $dataFileArg "http://$consulIpAddr:$consulHttpPort${url}?pretty"
}

function registerService() {
    service=$1
    instance=$2
    serviceIpAddr=$3
    port=$4

    dataFile=`createServiceJsonFile $service $instance $serviceIpAddr $port`

    runCurlPut "/v1/agent/service/register" "@$dataFile"
}

function createServiceId() {
    service=$1
    instance=$2
    serviceIpAddr=$3

    echo "$service${instance}_$serviceIpAddr"
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
        "Check": {
            "id": "'$serviceId'",
            "HTTP": "'$url'",
            "Interval": "10s"
        }
    }' > $jsonFile

    echo $jsonFile
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

    runCurlPut /v1/agent/service/deregister/$serviceId
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
    for service in $currentlyFailedServices
    do
        echo service :$service:
        count=${criticalFailures[$service]}
        
        if [[ $count == "" ]] 
        then
            echo Service $service not previously seen
            criticalFailures[$service]=0
        fi
    done

    for service in "${!criticalFailures[@]}"
    do 
        #echo $service:${criticalFailures[$service]}
        count=${criticalFailures[$service]}
        
        if [[ $currentlyFailedServices == *$service* ]] 
        then
            echo Increment $service
            criticalFailures[$service]=$((++count))
        else
            if [[ $count -le 1 ]] 
            then
                echo Remove $service
                unset criticalFailures[$service]
            else
                echo Decrement $service
                criticalFailures[$service]=$((--count))
            fi
        fi
    done

    echo Updated criticalFailures
    for service in "${!criticalFailures[@]}"
    do
        echo 'criticalFailures['$service']='${criticalFailures[$service]}
    done
}

function runChecks() {
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

    echo
    for state in critical warning
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
}

export consulIpAddr=172.17.8.101

setup

if test "$1" == "start"
then
    while true; 
    do 
        runChecks
        sleep 3 
    done
    exit 0
fi

if test "$1" == "stop"
then
    pkill monitor.sh
    return 2>/dev/null || exit 0
fi

# TODO: Do we need to expand this beyond register*Service and unregisterService?
if [[ `type -t $1` == "function" ]]
then
    ${1} $2 $3
    exit 0
fi

return 2>/dev/null || echo Usage: `basename $0` '[start|stop]' && exit 1

