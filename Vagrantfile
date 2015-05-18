# -*- mode: ruby -*-
# # vi: set ft=ruby :

require 'fileutils'

Vagrant.require_version ">= 1.6.5"

unless Vagrant.has_plugin?("vagrant-triggers")
raise Vagrant::Errors::VagrantError.new, "Please install the vagrant-triggers plugin running 'vagrant plugin install vagrant-triggers'"
end

CLOUD_CONFIG_PATH = File.join(File.dirname(__FILE__), "user-data")
CONFIG = File.join(File.dirname(__FILE__), "config.rb")

# Defaults for config options defined in CONFIG are in config.rb

# Attempt to apply the deprecated environment variable NUM_INSTANCES to
# $num_instances while allowing config.rb to override it
if ENV["NUM_INSTANCES"].to_i > 0 && ENV["NUM_INSTANCES"]
        $num_instances = ENV["NUM_INSTANCES"].to_i
end

if File.exist?(CONFIG)
    require CONFIG
end

# Use old vb_xxx config variables when set
def vm_gui
    $vb_gui.nil? ? $vm_gui : $vb_gui
end

def vm_memory
    $vb_memory.nil? ? $vm_memory : $vb_memory
end

def vm_cpus
    $vb_cpus.nil? ? $vm_cpus : $vb_cpus
end

Vagrant.configure("2") do |config|
    # always use Vagrants insecure key
    config.ssh.insert_key = false
    config.ssh.forward_agent = true;

    config.vm.box = "coreos-%s" % $update_channel

    # To fix the coreos release that vagrant uses
    # config.vm.box_version = "= 668.2.0"
    config.vm.box_url = "http://%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json" % $update_channel

    ["vmware_fusion", "vmware_workstation"].each do |vmware|
        config.vm.provider vmware do |v, override|
            override.vm.box_url = "http://%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant_vmware_fusion.json" % $update_channel
        end
    end


    # plugin conflict
    if Vagrant.has_plugin?("vagrant-vbguest") then
        config.vbguest.auto_update = false
    end

    (1..$num_instances).each do |i|
        $vmName = "%s-%02d" % [$instance_name_prefix, i] 
        ip = "172.17.8.#{i+100}"

        config.vm.provider :virtualbox do |v|
            # On VirtualBox, we don't have guest additions or a functional vboxsf
            # in CoreOS, so tell Vagrant that so it can be smarter.
            v.check_guest_additions = false
            v.functional_vboxsf         = false
            #v.name                                    = $vmName
        end

        config.vm.define vm_name = $vmName do |config|
            config.vm.hostname = vm_name

            if $enable_serial_logging
                logdir = File.join(File.dirname(__FILE__), "log")
                FileUtils.mkdir_p(logdir)

                serialFile = File.join(logdir, "%s-serial.txt" % vm_name)
                FileUtils.touch(serialFile)

                ["vmware_fusion", "vmware_workstation"].each do |vmware|
                    config.vm.provider vmware do |v, override|
                        v.vmx["serial0.present"] = "TRUE"
                        v.vmx["serial0.fileType"] = "file"
                        v.vmx["serial0.fileName"] = serialFile
                        v.vmx["serial0.tryNoRxLoss"] = "FALSE"
                    end
                end

                config.vm.provider :virtualbox do |vb, override|
                    vb.customize ["modifyvm", :id, "--uart1", "0x3F8", "4"]
                    vb.customize ["modifyvm", :id, "--uartmode1", serialFile]
                    # Don't let the clocks vary by more than 10 seconds
                    # From: http://stackoverflow.com/questions/19490652/how-to-sync-time-on-host-wake-up-within-virtualbox
                    vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 10000 ]
                end
            end

            if $expose_docker_tcp
                $guest_port = "2%s75" % $i;
                $host_port = $expose_docker_tcp + ($i.to_i * 100);
                config.vm.network "forwarded_port", guest: $guest_port, host: $host_port, auto_correct: true
            end

            # Create bridged network
            # config.vm.network "public_network", bridge: "en0: Ethernet"

            # NFS needs a host-only network to be created
            config.vm.network :private_network, ip: ip

            # TODO: Figure out how to get these numbers from adNimbusEnvironment
            # Allow port forwarding on the nginx port
            config.vm.network "forwarded_port", guest: 49160, host: 49160, auto_correct: true

            # TODO: For load testing purposes, allow the net location servers to be individually queried
            #config.vm.network "forwarded_port", guest: 49170, host: 49170, auto_correct: true

            ["vmware_fusion", "vmware_workstation"].each do |vmware|
                config.vm.provider vmware do |v|
                    v.gui = vm_gui
                    v.vmx['memsize'] = vm_memory
                    v.vmx['numvcpus'] = vm_cpus
                end
            end

            config.vm.provider :virtualbox do |vb|
                vb.gui = vm_gui
                vb.memory = vm_memory
                vb.cpus = vm_cpus
            end

            # Enable NFS for sharing the host machine into the VM.
            config.vm.synced_folder ".", "/home/core/share", id: "core", :nfs => true, :mount_options => ['nolock,vers=3,udp']

            # Load the WebContent Research project if available
            $webContentDir = ENV['webContentDir']
            if Dir.exists?($webContentDir)
                config.vm.synced_folder $webContentDir, "/home/core/WebContent", 
                    id: "WebContent", :nfs => true, :mount_options => ['nolock,vers=3,udp']
            end

            if $share_home
                config.vm.synced_folder ENV['HOME'], ENV['HOME'], id: "home", :nfs => true, :mount_options => ['nolock,vers=3,udp']
            end

            # Customize the environment.
            if File.exist?(CLOUD_CONFIG_PATH)
                config.vm.provision :file, :source => "#{CLOUD_CONFIG_PATH}", :destination => "/tmp/vagrantfile-user-data"
                config.vm.provision :shell, :inline => "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/", :privileged => true
            end
        end
    end
end

