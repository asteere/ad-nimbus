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
v ssh core-01 -- -R 60000:localhost:60000 -o ServerAliveInterval=60 -o StrictHostKeyChecking=no
cdad
cd LoadTests/JMeter
./runServer.sh

# On AWS ec2: If you want to run the test suite on one instance with the output dumped to a file in the container
# Upload the jmeter tar.gz or push then pull dockerhub
# Open port 50000 and 1099 on the instance's security policy
cdad
awsgetipaddresses

# For each instance you want to run JMeter
# The scps are only required if the image doesn't have the latest versions
scp "$adNimbusDir/registrySaves/$imageTag.tar.gz core@<publicIpAddress>:/home/core
scp "$adNimbusDir/LoadTests/JMeter/runServer.sh core@<publicIpAddress>:/home/core

ssh -R 60000:localhost:60000 -o ServerAliveInterval=60 -o StrictHostKeyChecking=no core@<publicIpAddress>

./runServer.sh

# 2. Run the client
# On Mac: 
cdad
cd LoadTests/JMeter
# Create comma separated list of remote JMeter server ip address 
./runJmeter.sh -Jremote_hosts=1.2.3.4,5.6.7.8

# Set the domain variable to the public ip address that is running nginx
# Make sure that the nginx port, 49160, is available to the network you are on

# Shutdown
# On the Mac
# Close JMeter
# Terminate the clusters
awsterminatecluster
