#! /bin/bash

set -e

. /etc/environment
. /home/core/share/adNimbusEnvironment

set +e

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
dataCenterArg="-dc superiorCoDataCenter"

serverArg=-server

#advertiseArg="-advertise=$COREOS_PUBLIC_IPV4"
bindArg="-bind=$COREOS_PUBLIC_IPV4"
clientArg="-client=$COREOS_PUBLIC_IPV4"

# TODO: figure out how to get the IP address of the first consul so everybody can join it
joinArg=""
for i in $clusterPrivateIpAddrs
do
    if test ! "$i" = "$COREOS_PUBLIC_IPV4"
    then
        joinArg="$joinArg -join=$i"
    fi
done
echo $joinArg

nodeArg="-node $hostname"

# TODO: Do all the consul servers and agents needs the UI or only some portion
uiDirArg="-ui-dir ${consulDir}/ui"

# TODO: do we want to always remove all the data. Probably only when we start the cluster the first time
consulDataDir=/tmp/data
rm -rf ${consulDataDir}
dataDirArg="-data-dir ${consulDataDir}"

configDirArg="-config-dir ${consulDir}/consul.d"

instance=$1
echo Starting instance $instance
case "$instance" in
1)
    echo start the first server

    bootstrapArg="-bootstrap"
    unset advertiseArg
    unset joinArg    
    
;;
2|3)
    echo start additional servers
;;
*)
    echo start agent
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
/usr/bin/docker run --name=${consulDockerTag} \
    --net=host \
    -P \
    --volume /var/run/docker.sock:/var/run/docker.sock \
    --volume /home/core/share/${consulService}:${consulDir} \
    --volume /home/core/share/${nginxService}:${nginxDir} \
    ${dockerImage} \
    ${consulDir}/${consulService} \
    agent $serverArg $bootstrapArg $advertiseArg $bindArg $clientArg $joinArg \
    $dataCenterArg \
    $uiDirArg $configDirArg \
    $dataDirArg \
    $nodeArg

