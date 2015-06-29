#! /bin/sh

# Bash like instructions for creating and running the demo on AWS. Assumes you are running from 
# Andy's account with a security group that is properly defined.
# On the Mac: 
# Create one ec2 instance from the latest us-west-2 HVM coreos image. Here is the latest Ami as of 6/25/2015
# URL: https://coreos.com/docs/running-coreos/cloud-providers/ec2/
awscreatestack ami-5d4d486d 1

# The ip address is available before the instance is ready. Monitor status using the browser. 
# Populate the instance with ad-nimbus and the aws credentials

# Either get ad-nimbus from s3 
awssyncmactos3
scp -r ~/.aws "$adNimbusDir"/.awsProfile core@`awsgetpublicipaddresses`:/home/core/
scp ~/.ssh/AdNimbusPrivateIPKeyPairUsWest2.pem core@`awsgetpublicipaddresses`:/home/core/.ssh

# Or get it from Mac
awscreatetar
awsscpadnimbus

# Either way, open ssh session to instance
awsopenssh

# Pull the data from s3 bucket
# Get the AWS cli container
docker pull asteere/aws-cli:aws-cli
. .awsProfile
awssyncs3toinstance
. $adNimbusDir/.coreosProfile

# Additional setup steps
$adNimbusDir/aws/prepImage.sh

# Copy the awscreateimage output line above and run it on the Mac. The line should look like the following:
#awscreateimage 172.31.4.77

# AWS shutsdown an instance, creates the image and starts the instance.

# Cleanup the stack and instance. It may take a couple of minutes before the ec2 and cloudformation web pages 
# show everything terminated.
awsdeletestack

# To Run the demo make sure the ec2 AMI page shows that the image is ready before creating the stack
# Mac:
awscreatestack
awsopenssh

# AWS EC2 instance:
fstartall

# Regression Testing: Follow the instructions in docs/RegressionTesting.md

# Load Tests: 
# MAC: Start a JMeter cluster
awscreatestack

# Follow instructions in jmeter/README.md
 
# When you are done you can terminate the instances but leave the stack for future clusters 
awsterminatecluster

# Or, delete the stack
awsdeletestack

