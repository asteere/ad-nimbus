Mac Setup
Install Vagrant, Docker, Docker2Boot, git, github
Create accounts on GitHub and DockerHub
Create your own ad-nimbus/master by forking the GitHug mark-larter/ad-nimbus/master branch 
Create a develop branch off your ad-nimbus/master
Clone your ad-nimbus/develop 

Add the contents of the .exampleProfile to your .profile. The .*Profile files have a lot of helper aliases and functions to do the repetitive work. In addition they handle getting the vagrant private key onto the vms to allow the fleetctl commands to work.

Starting and Using Vagrant/Docker/Coreos Cluster
The remaining instructions assume you have familiarized yourself with the .hostProfile and .coreosProfile files.

Open a mac terminal which will source your updated .profile

# The remaining instructions are written as if this was a shell script
cd "$VAGRANT_CWD"

# Ask Mark or Andy for the location/zip/tar of the maxmind database.
# Assuming it is a zip file in the Downloads directory on the mac
mkdir -p "$VAGRANT_CWD"/netlocation/src/data
cd "$VAGRANT_CWD"/netlocation/src/data
unzip ~/Downloads/maxMind-ss.zip
mv maxMind-ss maxMind

# The next step will create, provision and start the coreos VMs. This can take a while the first time. 
# Stick around until you are prompted for your password. After that you can get a cup of coffee.
v up

# Log in to one of the virtual machines
vsh1

. share/.coreosProfile

# Start the services for basic operations (nginx, confd, 1 netlocation, monitor)
fstartAll

# Although the command prompt will come back the services are not operational at this point. The following commands will provide status.
fluf

f status netlocation@1.service
f status nginx@1.service

# The output of the fluf command will indicate what IP address the nginx service/container is running. Open a browser
# and type in the nginx IP Address and port (49160). For example: 172.17.8.102:49160. 
# If everything is running correctly, you should get a JSON payload with your IP address.

# If you want to destroy all the services
fdestroy

# If you want to destroy a specific service
fdestroy netlocation@1.service

