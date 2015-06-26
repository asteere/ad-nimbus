#! /bin/bash

# Additional setup steps
ssh-keygen -y -f ~/.ssh/AdNimbusPrivateIPKeyPairUsWest2.pem >> ~/.ssh/authorized_keys 

# TODO: Preserve read, write, execute permissions while files are on s3

# Stop services and remove files to simulate a boot from a first-time image so coreos will create the right files
# Kudos: https://nickrandell.wordpress.com/2014/09/29/creating-a-coreos-cluster-on-linode/
sudo systemctl stop fleet
sudo systemctl stop etcd
sudo rm -r /etc/machine-id
sudo rm -r /var/lib/etcd/*
sudo rm -r /run/systemd/system/etcd.service.d
sudo rm -r /run/systemd/system/fleet.service.d
rm -f ~/.awsProfile ~/aws_ad-nimbus*tar.gz

echo Run the following command on the Mac
echo awscreateimage `ip addr | grep 'inet ' | grep eth0 | sed 's/.*inet \(.*\)\/.*brd.*/\1/'`

