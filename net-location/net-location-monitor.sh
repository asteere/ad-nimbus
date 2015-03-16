i#!=/bin/bash 

# Provide access to the variables that the services use
set -a
. /etc/environment
. /home/core/share/adNimbusEnvironment
set +x

function startAnotherService() {

}

function selectAndStopAService() {

}

function checkCpuUsage() {
    echo Pretending to check CPU Usage across all coreos running net-location
    # Get CPU Usage
}

function checkResponseTime() {
    curl -f ${COREOS_PUBLIC_IPV4}:49160; 
}

while true; 
do 
    checkCpuUsage
    sleep 20; 
done'

