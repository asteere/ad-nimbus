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

    dataFile=`createServiceJsonFile $service $instance`

    runCurlPut "/v1/agent/service/register" "@$dataFile"
}

function unregisterService() {
    serviceId=$1

    runCurlPut /v1/agent/service/deregister/$serviceId
}

function createServiceJsonFile() {
    service=$1
    instance=$2

    id="$service$instance"
    url="http://$COREOS_PUBLIC_IPV4:$netLocationGuestOsPort?ipAddress=198.243.23.131"

    jsonFile=/tmp/$service$instance.json

    echo '{
        "ID": "'$id'",
        "Name": "'$service'",
        "Tags": [
            "'$service'",
            "v1"
        ],
        "Address": "'$COREOS_PUBLIC_IPV4'",
        "Port": '$netLocationGuestOsPort',
        "Check": {
            "id": "'$id'",
            "HTTP": "'$url'",
            "Interval": "10s"
        }
    }' > $jsonFile

    echo $jsonFile
}

function registerNetLocationService() {
    instance=$1

    registerService netlocation $instance
}

function registerNginxService() {
    instance=$1

    registerService nginx $instance
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
    for i in critical warning
    do
        badNodes=`getStateOfService $i | awk '/ServiceID/ {gsub("\"", "", $NF); gsub(",", "", $NF); print $NF}'`
        if test "$badNodes" == ""
        then
            echo No services are in $i state
        else
            echo Services that are in $i state: 
            getStateOfService $i
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
    exit 0
fi

return 2>/dev/null || echo Usage: `basename $0` '[start|stop]' && exit 1

