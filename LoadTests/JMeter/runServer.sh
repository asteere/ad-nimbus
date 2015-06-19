#! /bin/bash
# Instructions for updating and running JMeter in a container
# FROM: https://registry.hub.docker.com/u/hauptmedia/jmeter/

if test `uname` == "Darwin"
then
    echo Error: This script is designed not designed to run on Darwin or Windows
    return 1
fi

echo Did you start the ssh session with reverse tunnelling'?' See README.md

# Run JMeter container on Vagrant/AWS coreos instance
export repo=asteere
export image=jmeter
export tag=0.1
export containerName=$repo/$image:$tag

set -x
docker images | grep "$repo/$image" | grep "$tag" 2>&1 > /dev/null
if test "$?" != 0
then
    tarFile=${image}-${tag}.tar.gz
    if test -d "$adNimbusDir/registrySaves"
    then
        tarFile="$adNimbusDir/registrySaves/$tarFile"
    fi
    docker load -i $tarFile
fi

# On Coreos/AWS: If you want to run the test suite on one instance with the output dumped to a file in the container
export SERVER_PORT=1099
export serverRmiLocalPort=50000
export dockerPorts="-p $serverRmiLocalPort:$serverRmiLocalPort -p $SERVER_PORT:$SERVER_PORT"
export jmeterArgs="-s -Jserver.rmi.localport=$serverRmiLocalPort -Djava.rmi.server.hostname=$COREOS_PUBLIC_IPV4 -Dserver_port=$SERVER_PORT"

docker run $dockerPorts --net=host -e 'JVM-ARGS="-Xms12G -Xmx12G"' -i -t --rm -v $(pwd):/root $containerName bin/jmeter $jmeterArgs -l /root/jmeter_${COREOS_PUBLIC_IPV4}_Samples.log -j /root/jmeter_${COREOS_PUBLIC_IPV4}.log 

# Fails: Connection refused: export jmeterArgs="-s -Jserver.rmi.localport=$serverRmiLocalPort -Djava.rmi.server.hostname=$COREOS_PUBLIC_IPV4 -Dserver_port=$SERVER_PORT"
# Fails: Connection refused: export jmeterArgs="-s -Jserver.rmi.localport=$serverRmiLocalPort -Djava.rmi.server.hostname=localhost -Dserver_port=$SERVER_PORT"

# Fail: docker run --priviledged
