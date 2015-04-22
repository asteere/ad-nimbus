#!/bin/bash 

# Provide access to the variables that the services use
set -a
. /etc/environment
. /home/core/share/adNimbusEnvironment
set +a

export curlOptions='-s -L'

function runCurlGet() {
    url=$1
    curl $curlOptions -X GET http://$consulIpAddr:$consulHttpPort"${url}"?pretty
}

function runCurlPut() {
    url=$1
    dataFile=$2
    curl $curlOptions -d @$dataFile http://$consulIpAddr:$consulHttpPort"${url}"?pretty
}

function runCurl() {
    method=$1
    url=$2
    curl $curlOptions -X $method ${url}?pretty
}

function addChecks() {
    # Registers a new local check
    runCurlPut /v1/agent/check/register 
}

function registerService() {
    # Registers a new local service
    runCurlPut /v1/agent/service/register 
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

function runChecks() {
    # Check that there is a raft leader
    leader=`getConsulLeader`
    echo Leader: $leader

    # check that there are peers
    peers=`getConsulPeers`
    echo Peers: $peers

    # Lists nodes in a given DC. Should equal numInstances
    nodes=`getConsulNodes`
    echo Nodes: $nodes

    # Lists the services provided by a node 
    ipAddrForNodes=`getConsulNodes | awk '/Address/ {gsub("\"", "", $NF); print $NF}'`
    for node in $ipAddrForNodes
    do
        servicesOnNode=`getANodesServices $node`
        if test "$servicesOnNode" == ""
        then
            echo Node $node is not running any services
        else
            echo Node $node is running $servicesOnNode
        fi
    done

    for i in critical warning
    do
        badNodes=`getStateOfService $i | awk '/service/ {gsub("\"", "", $NF); print $NF}'`
        if test "$badNodes" == ""
        then
            echo No services are in $i state
        else
            echo Services that are in $i state: $badNodes
        fi
    done
}

export consulIpAddr=172.17.8.101

return

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

echo Usage: `basename $0` '[start|stop]'
exit 1

