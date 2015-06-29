Mac Setup
Install Vagrant, Docker, Docker2Boot, git, github
Create accounts on GitHub and DockerHub
Create your own ad-nimbus/master by forking the GitHug mark-larter/ad-nimbus/master branch 
Create a develop branch off your ad-nimbus/master
Clone your ad-nimbus/aws_proto branch
cd to the cloned folder

Add the contents of the .exampleProfile to your .profile. The .*Profile files have a lot of helper aliases and functions to do the repetitive work and the nasty gotchas if you forget a step. In addition they handle getting the vagrant private key onto the vms to allow the fleetctl commands to work.

Correct the .awsProfile awsVariables securityGroup and s3bucket to match your configuration.

Starting and Using Vagrant/Docker/Coreos Cluster
The remaining instructions use functions defined in the .hostProfile, .coreosProfile, .awsProfile and .sharedProfile files.

Open a mac terminal which will source your updated .profile and .hostProfile. You should be in the $VAGRANT_CWD folder.

# The remaining instructions are written as if this was a shell script

# Ask Mark or Andy for the location/zip/tar of the maxmind database.
# Assuming it is a zip file in the Downloads directory on the mac
mkdir -p "$VAGRANT_CWD"/netlocation/data
cd "$VAGRANT_CWD"/netlocation/data
unzip ~/Downloads/maxMind-ss.zip
mv maxMind-ss maxMind

# Build all the containers. This may take awhile. Ignore any errors about pushing a docker image to dockerhub.
buildall

# The next step will create, provision and start the coreos VMs. This can take a while the first time. 
# Stick around until you are prompted for your password. After that you can get a cup of coffee.
vup

# Log in to one of the virtual machines
vsh 1

# Start the services for basic operations (consul, confd&nginx combo, netlocation, monitor)
# fstartall should finish with all the services setup and running. Fstartall will hang waiting for a condition to happen
fstartall

# Run fstatus at any point to iterate through the running services. Alternatively, you can run fstatus "somestring" so that only services with "somestring" in the name will be output.

# The checknetlocation function can be run to see if nginx, netlocation and maxmind are working correctly. 
# If checknetlocation is run too soon after fstartall, you may get a "Connection refused"

# If you want to destroy all the services
fdestroy

# If you want to destroy a specific service
fdestroy netlocation@1.service

# To see the last 100 lines of fleetctl service log entries for the monitor@1.service. Only a unique service name substring is needed.
fj -100 mon

# To tail the fleetctl service
fj -f netlo

# Instructions for regression testing the ad-nimbus emo are in demo/RegressionTesting.md

# Instructions for running the demo in AWS are in aws/README.md

# Instruction for running JMeter tests in Vagrant or AWS are in jmeter/README.md. The AWS instructions assume you have read the aws/README.md file.
