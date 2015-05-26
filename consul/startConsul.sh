#! /bin/bash

set -x

echo '=========================' `basename $0` args:$*: '=========================='

function sendSignal() {
    echo Sending $1 to consul 
    # TODO: Not sure the use cases where this is needed
    # docker kill -s $1

    if test "$instance" != ""
    then
        docker rm -f ${consulDockerTag}_$instance
    fi

    if test -f "$consulServerCfg"
    then
        rm -f "$consulServerCfg"
    fi
}

function setup() {
    trap 'sendSignal TERM' TERM
    trap 'sendSignal INT' INT 
    trap 'sendSignal QUIT' QUIT 
    trap 'sendSignal HUP' HUP
    trap 'sendSignal USR1' USR1

    if test "$1" == ""
    then
        echo Usage: `basename $0` instance
        exit 1
    fi

    set -a
        
    instance=$1

    for envFile in /etc/environment /home/core/share/adNimbusEnvironment /home/core/share/monitor/monitorEnvironment
    do  
        if test ! -f "$envFile"
        then
            echo Error: Unable to find envFile $envFile
            exit $exitCritical
        fi
        . "$envFile"
    done
    hostname=`uname -n`

    GOMAXPROCS=8

    consulServerCfg="$adNimbusTmp"/consulServer.cfg

    set +a

    # Consul needs this for preserving data across reboots
    mkdir -p "$adNimbusDir"/consul/consul.d/{bootstrap,client,server}
}

setup $*

# Get number of coreos instances. This works as long as all machines are running etcd ?servers?
# 
#numServers=`etcdctl ls -recursive _etcd/machines | wc -l`
clusterPrivateIpAddrs=`curl -s http://127.0.0.1:4001/v2/keys/_etcd/machines 2>/dev/null | \
    "$adNimbusDir"/devutils/jq '.node.nodes[].value' | \
    sed -e 's/.*%2F//' -e 's/%3.*//'`

numServers=`echo $clusterPrivateIpAddrs | wc -w`

if test $(($numServers % 2)) == 0 -a $numServers -lt 3
then 
    echo Warning: Even number of consul servers getting created. Consul does not recommend this.
fi

# TODO: Generalize this for larger number of servers.
case $numServers in
1|2)
    bootstrapExpect=1
    ;;
3|4)
    bootstrapExpect=3
    ;;
5|*)
    bootstrapExpect=5
    ;;
esac

echo etcd reported $numServers servers: $clusterPrivateIpAddrs. Setting bootstrap-expect to $bootstrapExpect.

# Get number instances of consul running
# TODO: Start the right number of consul agents and servers based on cluster size
dataCenterArg="-dc superiorDataCenter"

serverArg=-server

#advertiseArg="-advertise=$COREOS_PUBLIC_IPV4"
bindArg="-bind=$COREOS_PUBLIC_IPV4"
clientArg="-client=$COREOS_PUBLIC_IPV4"

# TODO: figure out how to get the IP address of the first consul so everybody can join it


# Telling each consul that there are multiple agents to retry with creates pockets of consul servers.
# TODO: This is probably my coding mistake, but due to time, hacking this in place.
retryJoinArg=""
if test "$instance" = "1"
then
    echo $COREOS_PUBLIC_IPV4 > "$consulServerCfg"
else
    for ctr in {1..120}
    do
        if test -f "$consulServerCfg"
        then
            bootStrapIpAddr=`cat $consulServerCfg`
            if test "$bootStrapIpAddr" != ""
            then 
                retryJoinArg="-retry-join=$bootStrapIpAddr"
                retryJoinArg="$retryJoinArg -retry-interval=5s"
                echo $retryJoinArg
                break
            fi
        else
            sleep 2
            if test "$ctr" -gt 60
            then
                echo Error: No $consulServerCfg file found with the consul server\'s IP address, exiting
                exit 1 
            fi
        fi
    done
fi

nodeArg="-node $hostname"

# TODO: Do all the consul servers and agents needs the UI or only some portion
uiDirArg="-ui-dir ${consulDir}/ui"

# TODO: do we want to always remove all the data. Probably only when we start the cluster the first time
# TODO: Do we want a common data area? Initially, there were problems that seemed to be related to this.
consulDataDir="$adNimbusTmp"/data
rm -rf ${consulDataDir}
dataDirArg="-data-dir ${consulDataDir}"

configDirArg="-config-dir ${consulDir}/consul.d"

# TODO: Handle more 5 and 7 servers in larger clusters
bootstrapExpectArg="-bootstrap-expect $bootstrapExpect"
case "$instance" in
1)
    echo Start the first server, instance=$instance

    unset advertiseArg
    unset retryJoinArg    
    ;;
2|3)
    echo start additional servers, instance=$instance
    ;;
*)
    echo start an agent, instance=$instance
    unset serverArg
    unset bootstrapExpectArg
    ;;
esac

dockerImage="${DOCKER_REGISTRY}/${consulService}:${consulDockerTag}"

#dockerImage=progrium/consul
#    --rm=true \
#    --hostname=$hostname \
#    --publish ${COREOS_PUBLIC_IPV4}:8300:8300 \
#    --publish ${COREOS_PUBLIC_IPV4}:8301:8301 \
#    --publish ${COREOS_PUBLIC_IPV4}:8301:8301/udp \
#    --publish ${COREOS_PUBLIC_IPV4}:8302:8302 \
#    --publish ${COREOS_PUBLIC_IPV4}:8302:8302/udp \
#    --publish ${COREOS_PUBLIC_IPV4}:8400:8400 \
#    --publish ${COREOS_PUBLIC_IPV4}:8500:8500 \
#    --publish ${COREOS_PUBLIC_IPV4}:53:53/udp \
#    --env "HOST_IP=${COREOS_PUBLIC_IPV4}" \

# Uncomment when running from the command line
#/usr/bin/docker rm -f ${consulDockerTag} > /dev/null 2>&1

/usr/bin/docker run \
    --name=${consulDockerTag}_${instance} \
    --net=host \
    -P \
    --volume=/var/run/docker.sock:/var/run/docker.sock \
    --volume="$adNimbusDir"/${consulService}:${consulDir} \
    --volume="$adNimbusDir"/${nginxService}:${nginxDir} \
    --volume="$adNimbusDir"/${monitorService}:${monitorDir} \
    --volume="$adNimbusTmp":${tmpDir} \
    ${dockerImage} \
    ${consulDir}/${consulService} \
    agent $serverArg $advertiseArg $bindArg $clientArg $retryJoinArg \
    $dataCenterArg \
    $uiDirArg $configDirArg \
    $dataDirArg \
    $bootstrapExpectArg \
    $nodeArg

