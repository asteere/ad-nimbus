#! /bin/sh

if test "$1" == "-d"
then
    set -x
fi

cmd=`basename $0`
if test -d "/home/core/share"
then
    cp $adNimbusDir/bin/$cmd "$adNimbusDir"/tmp
    "$adNimbusDir"/netlocation/startNetLocation startDockerBash /opt/tmp/$cmd
fi

# From: https://github.com/s3fs-fuse/s3fs-fuse/wiki/Installation%20Notes

# These weren't in the installation notes
yum update -y

# Just in case they become part of the container
yum remove fuse fuse-s3fs

yum install -y make tar

yum install -y automake autoconf

echo 'core:x:500:500:CoreOS Admin:/home/core:/bin/bash' >> /etc/passwd

#Run as root...

yum install -y gcc libstdc++-devel gcc-c++ curl-devel libxml2-devel openssl-devel mailcap # See (*2)

# There is a libfuse.so.2 when this is done but the pathing is wrong. Using the following instead
# From: http://tecadmin.net/mount-s3-bucket-centosrhel-ubuntu-using-s3fs/
yum install -y fuse-libs fuse-utils

#Can't use yum for fuse need a different version than is available

echo date > timestamp_beforeFuseRelease

fuseRelease=2.9.4
fuseTarGz=fuse-${fuseRelease}.tar.gz
curl -L http://sourceforge.net/projects/fuse/files/fuse-2.X/$fuseRelease/$fuseTarGz/download -o $fuseTarGz

tar zxvf $fuseTarGz

cd fuse-$fuseRelease/ && ./configure && make && make install

echo -e '\\n/usr/local/lib' >> /etc/ld.so.conf

ldconfig

# From: http://tecadmin.net/mount-s3-bucket-centosrhel-ubuntu-using-s3fs/
#modprobe

s3fsRelease=1.74
s3fs=s3fs-${s3fsRelease}
s3fsTarGz=$s3fs.tar.gz
curl -L https://github.com/s3fs-fuse/s3fs-fuse/archive/v1.74.tar.gz -o $s3fsTarGz

tar zxvf $s3fsTarGz

(cd s3fs-fuse-$s3fsRelease/ && autoreconf --install && export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig && ./configure --prefix=/usr && make && make install)

mkdir -p /tmp/cache
mkdir -p /opt/tmp/s3mnt
chmod 777 /opt/tmp/s3mnt

if test ! -f ~/.passwd-3fs
then
    if test "$AWS_ACCESS_KEY_ID" == ""
    then
        echo Please input AWS_ACCESS_KEY_ID
        read AWS_ACCESS_KEY_ID
    fi

    if test "$AWS_SECRET_ACCESS_KEY" == ""
    then
        echo Please input AWS_SECRET_ACCESS_KEY
        read AWS_SECRET_ACCESS_KEY
    fi

    echo $AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY > ~/.passwd-s3fs
    cat ~/.passwd-s3fs
    chmod 600 ~/.passwd-s3fs
fi

s3fs -o use_cache=/tmp/cache ad-nimbus-bucket /opt/tmp/s3mnt

mkdir -p /opt/tmp/s3fs/lib64
for i in libcrypto.so.10 libfuse.so.2 libfuse.so.2.9.2 libulockmgr.so.1 libulockmgr.so.1.0.1
do
    cp /lib64/$i /opt/tmp/s3fs/lib64
done

mkdir -p /opt/tmp/s3fs/local/bin
cp /usr/local/bin/fusermount /opt/tmp/s3fs
cp /usr/local/bin/ulockmgr_server /opt/tmp/s3fs

# Unmount an S3 bucket
# fusermount -u /opt/tmp/s3mnt

set +x
