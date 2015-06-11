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

# Create the adnimbus tar and put it on the image
function setupShare() {
    # For each instance ip address listed above
    # ssh into each instance, copy and paste the following commands
    tar zxvf ad-nimbus*tar.gz
    mv ad-nimbus share 
    mv Users/troppus/.ssh/AdNimbusPrivateIPKeyPairUsWest2.pem ~/.ssh 
    rm -rf Users
    ssh-agent
    sleep 2
    cd ~/.ssh 
    ssh-keygen -y -f AdNimbusPrivateIPKeyPairUsWest2.pem >> authorized_keys 
    ssh-add AdNimbusPrivateIPKeyPairUsWest2.pem
    cd
    . share/.coreosProfile

}

function openSshTerminal() {
    sshScript=/tmp/sshTerminal.sh

    printf '#! /bin/bash\n \
        ssh $1 -t \n
        tar zxvf ad-nimbus*tar.gz; \n
        mv ad-nimbus share;\n
        mv Users/troppus/.ssh/AdNimbusPrivateIPKeyPairUsWest2.pem ~/.ssh;\n
        rm -rf Users;\n
        ssh-agent;\n
        cd ~/.ssh;\n
        ssh-keygen -y -f AdNimbusPrivateIPKeyPairUsWest2.pem >> authorized_keys; \n
        ssh-add AdNimbusPrivateIPKeyPairUsWest2.pem;\n
        cd;
        . share/.coreosProfile;
        echo;\n
        bash -l\n' > $sshScript
    chmod +x $sshScript
    open -a Terminal.app $sshScript
}

if [[ `type -t $functionName` == "function" ]]
then
    ${functionName} $*
    exit 0
fi

if test "`uname -s`" == "Darwin"
then
    cdad
    createtar
    tarFile=`ls -t $adNimbusDir/../ad*tar.gz | head -1`
    ipAddrs=`awsgetclusteripaddress | sed 's/ssh //'` 
    for who in $ipAddrs
    do 
        scp "$tarFile" $who:/home/core
        openSshTerminal $who
    done
else
fi

# To shutdown the instances, delete the Auto Scaling Group defined for this cluster. Otherwise, more instances will be created.
