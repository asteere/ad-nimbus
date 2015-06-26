#! /bin/sh

# Bash like instructions for creating and running the demo on AWS. Assumes you are running from 
# Andy's account with a security group that is properly defined.
# On the Mac: 
# Create one ec2 instance from the latest us-west-2 HVM coreos image.
latestAmi=ami-5d4d486d  # latest Ami as of 6/25/2015
awscreatestack $latestAmi 1

# Populate the instance ad-nimbus and the aws credentials

# Either get ad-nimbus from s3 
awssyncmactos3
scp -r ~/.aws core@`awsgetpublicipaddresses`:/home/core/
scp -r "$adNimbusDir"/.awsProfile core@`awsgetpublicipaddresses`:/home/core/
scp -r "$adNimbusDir"/aws/prepImage.sh core@`awsgetpublicipaddresses`:/home/core/

# Or get it from Mac
awscreatetar
awsscpadnimbus

# Either way, open ssh session to instance
awsopenssh

# Pull the data from s3 bucket
# Get the AWS cli container
. .awsProfile
docker pull asteere/aws-cli:aws-cli
awssyncs3toinstance
. $adNimbusDir/.coreosProfile

# Additional setup steps
$adNimbusDir/aws/prepImage.sh

# Copy the awscreateimage output line above and run it on the Mac. The line should look like the following:
#awscreateimage 172.31.4.77

# Shutdown the instance by deleting the Auto Scaling Group defined for this stack. Otherwise, more instances will be created.
awsdeletestack

# To Run the demo create the stack
# Mac:
awscreatestack
awsopenssh

# On an AWS EC2 instance:
fstartall

# Follow the instructions in docs/RegressionTesting.md

# To start a JMeter cluster
awscreatestack

# When you are done delete the stack
awsdeletestack

# These instructions were from when I first started. Most likely incomplete and out-of-date
# Follow these instructions if you aren't running from the command line. 
# Open a browser here: https://coreos.com/docs/running-coreos/cloud-providers/ec2/
# Select the us-west2 (oregon) HVM and select "Launch Stack"
# Give it any name, take the template offerred
# Select Next
# Fill out the parameters. If not noted, use the default
# AllowSSHFrom: specify the IP Address you are using: curl ifconfig.me
# Echostar: 198.243.23.131/32
# Paul's Coffee: 72.42.70.227/32
# Home: 63.227.127.11/32
# DiscoveryURL: Get a new token: curl https://discovery.etcd.io/new
# InstanceType: t2.micro
# KeyPair: AdNimbusUsWest2
# Select Next
# Select Next unless you want to specify a tag
# Select Create

# Go to the EC2 instances web page
# Select one on the instances and select the security group listed
# Custom TCP Rules: 49160, 8500 with Source "My IP" address
# SSH: 22 with Source "My IP" address
# SSH: 22 with Source - security group id
# Custome TCP Rule: 1024-65535 with Source - security group id
# Custome UDP Rule: 8000-8500 with Source - security group id

