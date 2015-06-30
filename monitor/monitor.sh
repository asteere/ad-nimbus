#! /bin/bash 

function getIpAddrsInCluster() {
    fleetctl list-machines -fields=ip --no-legend
}

function setup() {
    set -a

    for envFile in /etc/environment /home/core/ad-nimbus/adNimbusEnvironment /home/core/ad-nimbus/monitor/monitorEnvironment
    do
        if test -f "$envFile"
        then
            . "$envFile"
        fi
    done 

    # TODO: When a check gets set should we set the consulIpAddr to that address so it runs local
    consulIpAddr=`getIpAddrsInCluster | head -1`

    curlOptions='-s -L'

    set +a

    rm -f "$adNimbusTmp"/checkCpu*
}

function runCurlGet() {
    url=$1
    curl $curlOptions -X GET http://$consulIpAddr:$consulHttpPort"${url}"?pretty
}

function runCurlPut() {
    useIpAddr=$1
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
    url=$5

    dataFile=`createServiceJsonFile $service $instance $serviceIpAddr $port $url`

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
    url=$5 

    serviceId="`createServiceId $service $instance $serviceIpAddr`"

    jsonFile=/tmp/$service$instance.json

    outputFile=$tmpDir/${serviceId}_$$.log

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
                "Timeout": "10s"
            },
            {
                "Id": "'${serviceId}'_cpu-util",
                "Name": "CPU utilization",
                "Notes": "'${serviceId}'_cpu-util",
                "Script": "'$monitorDir'/checkCpu.sh '$serviceId' > '$outputFile' 2>&1",
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
    port=$3

    # Use canned IP address so that all the fields are returned
    url="http://$serviceIpAddr:$port${netLocationTestUrl}"
    
    registerService netlocation $instance $serviceIpAddr $port $url
}

function registerNginxService() {
    instance=$1
    serviceIpAddr=$2
    port=$nginxGuestOsPort
    url="http://$serviceIpAddr:$port/consul-check/index.html"

    registerService nginx $instance $serviceIpAddr $port $url
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

    instance=`fleetctl list-units -fields=unit --no-legend | \
        grep $service | sed -e 's/.*@//' -e 's/.service//' | sort -n | head -1`


    fleetCtlUnit=$service@${instance}.service
    echo Stopping $fleetCtlUnit
    fleetctl stop $fleetCtlUnit
}

function startService() {
    serviceId=$1
    service=`echo $serviceId | sed -e 's/@.*//'`

    instance=`fleetctl list-units -fields=unit --no-legend | \
        grep $service | sed -e 's/.*@//' -e 's/.service//' | sort -n | tail -1`
    instance=$((++instance))

    cd "$adNimbusDir"/$service

    fleetCtlUnit=$service@${instance}.service
    echo Starting $fleetCtlUnit
    fleetctl start $fleetCtlUnit
}

declare -A criticalFailures

function addNewFailedService() {
    currentlyFailedServices=$1

    # Go through the list of currently failed services
    #   If a service in the currently failed services is not in previously failed services, add it and set count to 0
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
}

# Always call this function before using minNumberInstances and maxNumberInstances
function updateNumberInstances() {
    serviceType=$1
    
    serviceRootName=${serviceType}Root

    # Kudos: indirect referencing: http://www.tldp.org/LDP/abs/html/ivr.html
    eval serviceRootValue=\$$serviceRootName

    minVarName=min${serviceRootValue}Services

    # Kudos: double parantheses: http://www.tldp.org/LDP/abs/html/dblparens.html
    minNumberInstances=$((minVarName))

    maxVarName=max${serviceRootValue}Services
    maxNumberInstances=$((maxVarName))
}

function updateCriticalFailureList() {
    currentlyFailedServices=$1

    # TODO: handle different services
    dataCenterNetLocationFailures=0

    # Go through the list of previously failed services
    #   If the previously failed service is in the list of currently failed servies, increment
    #   If the previously failed service is NOT in the list of currently failed servies, decrement
    for svcIndex in "${!criticalFailures[@]}"
    do 
        serviceType=`echo $svcIndex | sed 's/@.*//'`

        #echo $svcIndex:${criticalFailures[$svcIndex]}
        count=${criticalFailures[$svcIndex]}

        updateNumberInstances $serviceType
        
        if [[ $currentlyFailedServices == *$svcIndex* ]] 
        then
            echo Increment $svcIndex criticality count
            criticalFailures[$svcIndex]=$((++count))
            numNetLocationInstances=`getNumberLoadedActiveRunningServices $serviceType`
            echo "${criticalFailures[$svcIndex]}" -gt "$criticalFailuresHighWaterMark" -a \
                "$numNetLocationInstances" -lt "$maxNumberInstances"
            if test "${criticalFailures[$svcIndex]}" -gt "$criticalFailuresHighWaterMark" 
            then
                # Reset the counter to let the service run awhile and see if the problem has cleared or will clear up
                unset criticalFailures[$svcIndex]

                if test "$numNetLocationInstances" -lt "$maxNumberInstances"
                then
                    startService $svcIndex
                fi
            fi
        else
            if [[ "$count" -le 1 ]] 
            then
                echo Remove $svcIndex criticality count
                unset criticalFailures[$svcIndex]
                # TODO: Let the quiet period determine services to stop
                #if test "$numNetLocationInstances" -gt "$minNumberInstances"
                #then
                #    stopService $svcIndex
                #fi
            else
                echo Decrement $svcIndex criticality count
                criticalFailures[$svcIndex]=$((--count))
            fi
        fi

        # Count the number of netlocation services that have failures.
        if [[ "$netLocationService" == "$serviceType" ]] 
        then
            echo Increment number of $serviceType failures in cluster
            dataCenterNetLocationFailures=$((dataCenterNetLocationFailures + 1))
            resetClock
        fi
    done
}

function handleCriticalHealthChecks() {
    currentlyFailedServices=`getStateOfService critical | \
            # User ServiceID as consul requires that to be unique
            awk '/ServiceID/ {gsub("\"", "", $NF); gsub(",", "", $NF); print $NF}' | \
            sort -u`

    addNewFailedService "$currentlyFailedServices"

    serviceType=netlocation

    updateCriticalFailureList "$currentlyFailedServices"

    stopServicesIfErrorFree $serviceType

    numNetLocationInstances=`getNumberLoadedActiveRunningServices $serviceType`
    echo Number of $serviceType services: $numNetLocationInstances
    echo Number of $serviceType services that have had critical errors that haven\'t expired: $dataCenterNetLocationFailures
}

function resetClock() {
    clockStart=0
}

function stopServicesIfErrorFree() {
    serviceType=$1

    # If the number of dataCenterNetLocationFailures == 0 and more than X amount of time has passed, stop another service   
    if test "$dataCenterNetLocationFailures" -gt 0 
    then
        return
    fi

    if test "$clockStart" == 0
    then
        clockStart=$(date +%s)
    fi

    currentTime=$(date +%s)
    elapsedTime=$((currentTime - clockStart))

    updateNumberInstances $serviceType
    numRunningServices=`getNumberLoadedActiveRunningServices $serviceType`
    if test "$elapsedTime" -gt "$errorFreePeriod" -a "$numRunningServices" -gt "$minNumberInstances"
    then
        stopService $serviceType
        resetClock
    fi

    # Only harvest in times of error-free operation.
    # TODO: This may need to be revisited if we were to run out of resources
    harvestStoppedServices $serviceType
}

function debugOutput() {
    echo '*********************'
    fleetctl list-units -fields=unit,load,active,sub --no-legend 
    echo '======================'
    fleetctl list-units -fields=unit,load,active,sub --no-legend | \
        grep $serviceType | \
        grep -e 'loaded\sactive\srunning' -e 'loaded\sactivating' 
    echo '+++++++++++++++++++++++'
}

function getNumberLoadedActiveRunningServices() {
    serviceType=$1

    fleetctl list-units -fields=unit,load,active,sub --no-legend | \
        grep $serviceType | \
        grep -e 'loaded\sactive' -e 'loaded\sactivating' | \
        wc -l
}

function getNumberServices() {
    instance=$1

    fleetctl list-units --no-legend | grep $instance | wc -l
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

function getEtcdNodes() {
    curl -s http://127.0.0.1:4001/v2/keys/_etcd/machines 2>/dev/null | \
        "$adNimbusDir"/bin/jq '.node.nodes[].value' 
}

function runOtherChecks() {
    configRbFile="$adNimbusDir"/config.rb
    numConfigRbInstances=`grep '$num_instances=' "$configRbFile" | sed 's/.*=//'`
    numEtcdNodes=`getEtcdNodes | wc -l`
    if test "$numEtcdNodes" != "$numConfigRbInstances"
    then
        echo "Error: The number of etcd nodes($numEtcdNodes) doesn't match the number configured by vagrant($numConfigRbInstances) in config.rb file".
    fi
    echo "The number of nodes in etcd($numEtcdNodes) matches num_instances in $configRbFile($numConfigRbInstances)"

    echo
    numConsulNodes=`getConsulNodes | grep Node | wc -l`
    if test "$numConsulNodes" != "$numEtcdNodes"
    then
        echo Error: The number of consul nodes $numConsulNodes does not equals the number of etcd nodes $numEtcdNodes
    else
        echo The number of consul nodes $numConsulNodes equals the number of etcd nodes $numEtcdNodes
    fi

    # TODO: Check that the consul nodes haven't splintered

    # Check that there is a raft leader
    echo
    leader=`getConsulLeader`
    if test "$leader" == "" -o "$leader" == "[]"
    then
        echo Error: consul cluster does not have a leader
    else
        echo Leader: $leader
    fi

    # Check that there are peers
    echo
    peers=`getConsulPeers`
    echo Peers: $peers

    echo
    dataCenters=`getDataCenters`
    if test "$dataCenters" == "" -o "$dataCenters" == "[]"
    then
        echo Error: no data centers have been defined
    else
        echo Known datacenters: $dataCenters
    fi

    echo
    echo List services running in datacenter
    getServicesInDataCenter
    
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
    for svc in nginx netlocation consul
    do
        expectedNum=1
        if test "$svc" == "consul"
        then
            expectedNum=$numEtcdNodes
        fi

        echo $svc: 
        numSvcs=`getNumberServices $svc`
        if test "$numSvcs" -lt "$expectedNum"
        then
            echo Critical: There are only $numSvcs fleetctl $svc services running. Expected $expectedNum
            fleetctl list-units -fields=unit --no-legend | grep $svc 
        fi

        echo Consul reports the following services
        getNodesInService $svc
        echo

        # Consul will return an empty array "[]" or two characters if the service isn't known to consul
        if test `getNodesInService $svc | wc -m` -lt 3
        then
            echo Critical: There are no $svc services running known to consul
        fi
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
            echo
        fi

        if [[ $state == "critical" ]]
        then
            echo
            handleCriticalHealthChecks
        fi
    done

    dumpCriticalFailures
}

function harvestStoppedServices() {
    serviceType=$1

    fleetctl destroy `fleetctl list-units -fields=unit,load,active,sub --no-legend | \
        grep -e 'loaded\sfailed\sfailed' -e 'loaded\sinactive\sdead' | \
        grep $serviceType | \
        awk '{print $1}'`
}

runAll=false

resetClock

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

functionName=$1
shift 1

instance=$2
if test "$instance" == ""
then
    instance=1
fi

if test "$functionName" == "start"
then
    while true; 
    do 
        # Run setup each time to allow dynamic changes of controlling variables
        setup

        runChecks

        sleep $monitorRunChecksInterval 
        echo
        echo '==================================================================='
    done
    exit 0
fi

if test "$functionName" == "stop"
then
    pkill monitor.sh
    return 2>/dev/null || exit 0
fi

setup

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi

return 2>/dev/null || echo Usage: `basename $0` 'functionName functionArgs' && exit 1

