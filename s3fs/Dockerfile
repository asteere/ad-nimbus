# Base OS.
FROM centos:latest

MAINTAINER Andy Steere 

# From: https://github.com/s3fs-fuse/s3fs-fuse/wiki/Installation%20Notes

# These weren't in the installation notes
yum update -y

yum install -y make tar

yum install -y automake autoconf

echo 'core:x:500:500:CoreOS Admin:/home/core:/bin/bash' >> /etc/passwd

#Run as root...

yum install -y gcc libstdc++-devel gcc-c++ curl-devel libxml2-devel openssl-devel mailcap # See (*2)

#Can't use yum for fuse need a different version than is available

ENV fuseRelease 2.9.4
ENV fuseTarGz fuse-${fuseRelease}.tar.gz
curl -L http://sourceforge.net/projects/fuse/files/fuse-2.X/$fuseRelease/$fuseTarGz/download -o $fuseTarGz

tar zxvf $fuseTarGz

cd fuse-$fuseRelease/ && ./configure && make && make install

echo -e '\\n/usr/local/lib' >> /etc/ld.so.conf

ldconfig

# From: http://tecadmin.net/mount-s3-bucket-centosrhel-ubuntu-using-s3fs/
#modprobe

ENV s3fsRelease 1.74
ENV s3fs s3fs-${s3fsRelease}
ENV s3fsTarGz $s3fs.tar.gz
curl -L https://github.com/s3fs-fuse/s3fs-fuse/archive/v1.74.tar.gz -o $s3fsTarGz

tar zxvf $s3fsTarGz

(cd s3fs-fuse-$s3fsRelease/ && autoreconf --install && export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig && ./configure --prefix=/usr && make && make install)

# There is a libfuse.so.2 when this is done but the pathing is wrong. Using the following instead
# From: http://tecadmin.net/mount-s3-bucket-centosrhel-ubuntu-using-s3fs/
yum install -y fuse-libs fuse-utils

mkdir /tmp/cache
mkdir /opt/tmp/s3mnt
chmod 777 /opt/tmp/s3mnt
s3fs -o use_cache=/tmp/cache ad-nimbus-bucket /opt/tmp/s3mnt

for i in libcrypto.so.10  libfuse.so.2  libfuse.so.2.9.2  libulockmgr.so.1  libulockmgr.so.1.0.1
do
    cp /lib64/$i /opt/tmp/s3fs/lib64
done


