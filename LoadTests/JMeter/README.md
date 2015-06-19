# Instructions for updating and running JMeter in a container
# From: https://registry.hub.docker.com/u/hauptmedia/jmeter/

cdad
cd LoadTests/JMeter

# Build JMeter container
# On Mac: Update the Dockerfile with the latest release and any needed JMeter plugins. Update tag
image=jmeter
tag=0.1
containerName=asteere/$image:$tag
cd ..; docker build --tag $containerName JMeter; cd JMeter

imageTag=$image-$tag
docker save -o $adNimbusDir/registrySaves/$imageTag.tar $containerName
gzip $adNimbusDir/registrySaves/$imageTag.tar

# To run JMeter in a remote setup
# 1. Run the server(s)
# Vagrant
# On mac: Make sure that ports 50000 and 1099 are forwarded in the Vagrantfile. 
# TODO: Allow more than once vagrant instance to run jmeter server by forwarding consecutive ports 5000 and 1099 
# for each instance in the Vagrantfile and udate runServer.sh to know which ports to use.
v ssh core-01 -- -R 60000:localhost:60000 -o ServerAliveInterval=60 -o StrictHostKeyChecking=no
./runServer.sh

# On AWS ec2: If you want to run the test suite on one instance with the output dumped to a file in the container
# Upload the jmeter tar.gz or push then pull dockerhub
# Open port 50000 and 1099 on the instance
cdad
awsgetipaddresses

# For each instance you want to run JMeter
scp "$adNimbusDir/registrySaves/$imageTag.tar.gz core@<publicIpAddress>:/home/core
scp "$adNimbusDir/LoadTests/JMeter/runServer.sh core@<publicIpAddress>:/home/core
ssh -R 60000:localhost:60000 -o ServerAliveInterval=60 -o StrictHostKeyChecking=no core@<publicIpAddress>
docker load -i $imageTag.tar.gz
./runServer.sh

# 2. Run the client
# On Mac: 
cdad
cd LoadTests/JMeter
# Create comma separated list of remote JMeter server ip address 
remote_hosts="-Jremote_hosts=1.2.3.4,5.6.7.8"
./runjmeter.sh  $remote_hosts

