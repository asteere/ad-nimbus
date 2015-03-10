function startnet-location() {
    service=net-location

    cd ~/share/$service

    fleetctl start ${service}@{1..4}.service

    cd -
}

function startnginx() {
    service=nginx

    cd ~/share/$service

    fleetctl start ${service}@1.service

    cd -
}

function buildnginx() {
    buildContainer nginx
}

function buildnet-location() {
    buildContainer net-location
}

function buildContainer() {
    cdad

    # this will result in two repositories asteere/nginx:latest and nginx:latest containing collections of images
    runDocker build --tag asteere/"$1":raptor $1 
    if test ! $? == 0
    then
        return
    fi

    #dlogin 
    if test ! $? == 0
    then
        return
    fi

    runDocker push asteere/"$1":raptor

    cd -

}

function fdestroy() {
    if test "$1" = ""
    then
        svcs=$(fleetctl list-unit-files | awk '{print $1}')
    else
        svcs=$1
    fi

    for i in $svcs
    do
        fleetctl destroy $i
    done
    fluf
}

function getListOfVms() {
    vbm list vms | awk '{print $1}' | sed 's/"//g'
}

function getvminfo() {
    for vm in  `getListOfVms | grep $1`
    do
        echo 
        echo '********************************************************'
        echo
        echo VM: $vm
        vbm showvminfo $vm
    done 
}

function vdestroy() {
    if test "$1" = ""
    then
        vboxes=`v status | grep virtualbox | awk '{print $1}'`
    else
        vboxes=$1
    fi

    for i in $vboxes
    do 
        v destroy --force $i

        machineDir=".vagrant/machines/$i"
        if test -d "$machineDir"
        then
            rm -r "$machineDir"
        fi

    done

    vms=`getListOfVms | grep -v boot2docker`
    if test ! "$1" == ""
    then
        vms=`echo $vms | grep $1`
    fi
    for vm in $vms
    do 
        vbm controlvm $vm poweroff 
        vbm unregistervm --delete $vm
    done

    echo Remaining vms
    getListOfVms

    echo vgs
    vgs

    echo vagrant status
    #vagrant status
}

function setupDocker() {
    if test ! "$DOCKER_HOST" == ""
    then
        # boot2docker already setup
        return
    fi

    (which boot2docker) &> /dev/null
    if test "$?" == 0
    then
        b2dstatus=`boot2docker status 2>&1`
        echo $b2dstatus
        echo $b2dstatus | grep "machine not exist" 2>&1 > /dev/null
        if test $? == 0
        then
            echo boot2docker init
            boot2docker init
        elif test ! "$b2dstatus" == "running"
        then
            echo boot2docker up
            boot2docker up
        fi
        $(boot2docker shellinit)
    fi
}

function runDocker() {
    setupDocker

    docker $*
}

function dlogin() {
    docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PWD
}

alias vbm=VBoxManage
alias gvmi=getvminfo
alias v=vagrant
alias vs='vagrant status'
alias vgs='vagrant global-status'
alias vsh1='vagrant ssh core-01'
alias vsh2='vagrant ssh core-02'
alias vsh3='vagrant ssh core-03'
alias vsh4='vagrant ssh core-04'
alias vsh5='vagrant ssh core-05'

alias b2d=boot2docker

alias cdad="cd $VAGRANT_CWD"

alias dps='runDocker ps -a'
alias dpsa='runDocker ps -a'
alias di='runDocker images'
alias d='runDocker'

alias f=fleetctl
alias flm='fleetctl list-machines -l'
alias flu='fleetctl list-units'
alias fluf='fleetctl list-unit-files'
alias ftunnel='fleetctl --tunnel 10.10.10.10'

# TODO: grep on OS name is somewhat fragile
uname -a | grep Linux > /dev/null
if test "$?" == 1
then
    # Setup Mac/Windows
    if test "$VAGRANT_CWD" == ""
    then
        echo This .profile assumes that VAGRANT_CWD has been exported and set it to your ad-nimbus folder on the host machine. 
        echo If VAGRANT_CWD is set, things like fleetctl status 'net-location@1.service' will work. Thanks.
        echo For example:
        echo '    export VAGRANT_CWD=~/Research/asteere/ad-nimbus'
    fi

    if test -d "$VAGRANT_CWD"
    then
        cdad
    fi

    # Make vagrant's key accessible to coreos 
    vagrantInsecureKey=insecure_private_key
    if test -f ~/.vagrant.d/insecure_private_key
    then
        cp ~/.vagrant.d/insecure_private_key .
    fi

    # Custom bash prompt via kirsle.net/wizards/ps1.html
    export PS1="\[$(tput setaf 5)\]\u@\[$(tput setaf 4)\]\h:\[$(tput setaf 2)\]\w:\n\[$(tput setaf 0)\]$ \[$(tput sgr0)\]"

else
    # Do all the coreos setup

    cd share

    ssh-add -L | grep insecure_private_key 2>&1 > /dev/null
    if test ! $? == 0
    then
        ssh-add insecure_private_key
    fi

fi

export CLICOLOR=1

# Setup fleetctl status
if test "$SSH_AUTH_SOCK" == ""
then
    eval $(ssh-agent)
fi

# Setting PATH for Python 3.4
# The orginal version is saved in .profile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.4/bin:${PATH}"
export PATH


