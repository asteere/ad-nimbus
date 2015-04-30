#! /bin/bash

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

trap 'sendSignal TERM' TERM
trap 'sendSignal INT' INT 
trap 'sendSignal QUIT' QUIT 
trap 'sendSignal HUP' HUP
trap 'sendSignal USR1' USR1

if test "$1" == ""
then
    echo Usage: `basename $0` consulInstanceNumber
    exit 1
fi

instance=$1
consulServerCfg=/home/core/share/consul/tmp/consulServer.cfg

set -a
    
for envFile in /etc/environment /home/core/share/adNimbusEnvironment /home/core/share/monitor/monitorEnvironment
do  
    if test ! -f "$envFile"
    then
        echo Error: Unable to find envFile $envFile
        exit $exitCritical
    fi
    . "$envFile"
done

set +a

hostname=`uname -n`

export GOMAXPROCS=8

# Get number of coreos instances. This works as long as all machines are running etcd ?servers?
# 
#numServers=`etcdctl ls -recursive _etcd/machines | wc -l`
curlOutput=`curl -s http://127.0.0.1:4001/v2/keys/_etcd/machines 2>/dev/null | /home/core/share/devutils/jq '.node.nodes[].value'`

clusterPrivateIpAddrs=`curl -s http://127.0.0.1:4001/v2/keys/_etcd/machines 2>/dev/null | /home/core/share/devutils/jq '.node.nodes[].value' | sed -e 's/.*%2F//' -e 's/%3.*//'`
numServers=`echo $clusterPrivateIpAddrs | wc -w`

echo etcd reported $numServers servers $clusterPrivateIpAddrs

# TODO: Override results while in initial development
numServers=2

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
    for ctr in {1..60}
    do
        if test -f "$consulServerCfg"
        then
            bootStrapIpAddr=`cat $consulServerCfg`
            if test "$bootStrapIpAddr" != ""
            then 
                retryJoinArg="--retry-join=$bootStrapIpAddr"
                retryJoinArg="$retryJoinArg --retry-interval=10s"
                echo $retryJoinArg
                break
            fi
        else
            sleep 2
            if test $ctr >= 60
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
consulDataDir=/tmp/data
rm -rf ${consulDataDir}
dataDirArg="-data-dir ${consulDataDir}"

configDirArg="-config-dir ${consulDir}/consul.d"

case "$instance" in
1)
    echo Start the first server, instance=$instance

    bootstrapArg="-bootstrap"
    unset advertiseArg
    unset retryJoinArg    
    
;;
2|3)
    echo start additional servers, instance=$instance
;;
*)
    echo start an agent, instance=$instance
    unset serverArg
;;
esac

# Find the smallest odd number greater than 1
# If the number instances in less expected servers, start another
# Otherwise, start agent with UI

dockerImage="${consulDockerRegistry}/${consulService}:${consulDockerTag}"

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

set -x
/usr/bin/docker run \
    --name=${consulDockerTag}_${instance} \
    --net=host \
    -P \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume /home/core/share/${consulService}:${consulDir} \
    --volume /home/core/share/${nginxService}:${nginxDir} \
    --volume /home/core/share/${monitorService}:${monitorDir} \
    ${dockerImage} \
    ${consulDir}/${consulService} \
    agent $serverArg $bootstrapArg $advertiseArg $bindArg $clientArg $retryJoinArg \
    $dataCenterArg \
    $uiDirArg $configDirArg \
    $dataDirArg \
    $nodeArg

