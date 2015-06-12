#! /bin/sh
# From: https://nickrandell.wordpress.com/2014/09/29/creating-a-coreos-cluster-on-linode/

# Steps to prepare coreos ad-nimbus instance for image
sudo systemctl stop fleet
sudo systemctl stop etcd
sudo rm -rf /etc/machine-id
sudo rm -rf /var/lib/etcd/*
sudo rm -rf /run/systemd/system/etcd.service.d
sudo rm -rf /run/systemd/system/fleet.service.d
ssh-keygen -y -f ~/.ssh/AdNimbusPrivateIPKeyPairUsWest2.pem >> ~/.ssh/authorized_keys

echo Save the image

