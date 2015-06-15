#! /bin/sh

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

# On the Mac: Create the adnimbus tar and put it on all the running images
awscreatetar
awsscpadnimbus

# For each instance ip address listed above
# ssh into each instance, copy and paste the following commands
tar zxvf aws_ad-nimbus*tar.gz
mv ad-nimbus share 
mv Users/troppus/.ssh/AdNimbusPrivateIPKeyPairUsWest2.pem ~/.ssh 
rm -rf Users
. share/.coreosProfile
cd ~/.ssh 
ssh-keygen -y -f AdNimbusPrivateIPKeyPairUsWest2.pem >> authorized_keys 

# Stop services and remove files to simulate a pre-first-time boot so coreos will create the right files
sudo systemctl stop fleet
sudo systemctl stop etcd
sudo rm -r /etc/machine-id
sudo rm -r /var/lib/etcd/*
sudo rm -r /run/systemd/system/etcd.service.d
sudo rm -r /run/systemd/system/fleet.service.d

# From the Mac: Save the image
awscreateimage

# To shutdown the instances, delete the Auto Scaling Group defined for this stack. Otherwise, more instances will be created.
awsdeletestack
