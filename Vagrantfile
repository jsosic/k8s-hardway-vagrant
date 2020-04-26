# -*- mode: ruby -*-
# vi: set ft=ruby :

def set_resources(vm, options)
  vm.provider :virtualbox do |v|
    v.cpus   = options[:cpu]
    v.memory = options[:ram]
  end
end

Vagrant.configure(2) do |config|
  config.ssh.insert_key = false
  config.ssh.forward_agent = !!ENV['VAGRANT_SSH_FORWARD']

  # VirtualBox
  config.vm.provider :virtualbox do |v|
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--ioapic", "on"]
  end

  config.vm.box = "centos/7"
  config.vm.network :forwarded_port, guest:  22, host: 4222, id: "ssh"

  # CentOS - Kubernetes controller(s)
  (1..3).each do |index|
    config.vm.define :"controller0#{index}" do |controller|
      set_resources(controller.vm, cpu: 1, ram: 2048)
      controller.vm.hostname = "controller0#{index}.heartbeat.lan"
      controller.vm.network :forwarded_port, guest: 22, host: "2401#{index}", id: "ssh"
      controller.vm.network :private_network, ip: "10.240.0.10#{index}", :netmask => "255.255.255.0", virtualbox__intnet: "kubernetes"
      controller.vm.provision "shell", path: "scripts/provision/controller.sh"
    end
  end

  # CentOS - Kubernetes worker(s)
  (1..3).each do |index|
    config.vm.define :"worker0#{index}" do |worker|
      set_resources(worker.vm, cpu:1, ram: 1024)
      worker.vm.hostname = "worker0#{index}.heartbeat.lan"
      worker.vm.network :forwarded_port, guest: 22, host: "2402#{index}", id: "ssh"
      worker.vm.network :private_network, ip: "10.240.0.20#{index}", :netmask => "255.255.255.0", virtualbox__intnet: "kubernetes"
      worker.vm.provision "shell", path: "scripts/provision/worker.sh"
    end
  end
end
