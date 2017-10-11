# -*- mode: ruby -*-
# vi: set ft=ruby :

guest_os = "ubuntu/xenial64"

nodes = [
  { :hostname => 'master1', :ram => 512, :ip => '192.168.2.10', :roles => ['mysql', 'master1'] },
  { :hostname => 'master2', :ram => 512, :ip => '192.168.2.20' , :roles => ['mysql', 'master2'] },
  { :hostname => 'slave1', :ram => 512, :ip => '192.168.2.30' , :roles => ['mysql', 'slave'] },
]

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  nodes.each do |node|
    config.vm.define node[:hostname] do |nodeconfig|
      nodeconfig.vm.box = guest_os
      nodeconfig.vm.network "private_network", ip: node[:ip]
      nodeconfig.vm.hostname = node[:hostname] + ".box"

      config.vm.provider "virtualbox" do |vb|
        vb.gui = false
        vb.name = node[:hostname]
        vb.check_guest_additions = false
        vb.memory = node[:ram]
      end

      config.vm.synced_folder ".", "/vagrant"

      nodeconfig.vm.provision "shell", privileged: true, path: "scripts/bootstrap.sh"

      node[:roles].each do |role|
        nodeconfig.vm.provision :shell, privileged: true, path: "scripts/#{role}.sh"

      end
    end
  end

end
