#! /bin/sh

# Follow these instructions if you aren't running from the command line. Note: these may be out-of-date
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

# Follow these instructions if you are running from the command line.
# On the Mac: Create the adnimbus tar and scp the tar file on a us-west2 coreos image.
# Replace ami-c5162ef5 with the latest us-west2 aws coreos HVM image id 
# from: https://coreos.com/docs/running-coreos/cloud-providers/ec2/
awscreatestack ami-c5162ef5 1
awscreatetar
awsscpadnimbus
awsopenssh

# For each instance ip address listed above
# ssh into each instance, copy and paste the following commands
tar zxvf aws_ad-nimbus*tar.gz
mv ad-nimbus share 
mv Users/troppus/.ssh/AdNimbusPrivateIPKeyPairUsWest2.pem ~/.ssh 
rm -rf Users
ssh-keygen -y -f ~/.ssh/AdNimbusPrivateIPKeyPairUsWest2.pem >> ~/.ssh/authorized_keys 
. share/.coreosProfile
echo Did any of the commands fail'?'

# Stop services and remove files to simulate a boot from a first-time image so coreos will create the right files
sudo systemctl stop fleet
sudo systemctl stop etcd
sudo rm -r /etc/machine-id
sudo rm -r /var/lib/etcd/*
sudo rm -r /run/systemd/system/etcd.service.d
sudo rm -r /run/systemd/system/fleet.service.d
echo awscreateimage `ip addr | grep 'inet ' | grep eth0 | sed 's/.*inet \(.*\)\/.*brd.*/\1/'`

# Copy the awscreateimage output line created above and run it on the Mac. The line should look like
#awscreateimage 172.31.4.77

# To shutdown the instances, delete the Auto Scaling Group defined for this stack. Otherwise, more instances will be created.
awsdeletestack

# To Run the demo
# Mac:
awscreatestack
awsopenssh

# AWS EC2 instance:
fstartall

# Follow the instructions in docs/RegressionTesting.md

# When you are done delete the stack
awsdeletestack
