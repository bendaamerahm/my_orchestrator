Vagrant.configure("2") do |config|
    # api node
    config.vm.define "api" do |node|
      node.vm.box = "ubuntu/focal64"
      node.vm.network "forwarded_port", guest: 8000, host: 8000
      node.vm.synced_folder ".", "/tmp/strivly"
  
      node.vm.provision "shell", inline: <<-SHELL
        # api
        cd /tmp/strivly
        chmod +x api.sh
        ./api.sh &
      SHELL
    end
  
    # worker node
    config.vm.define "worker" do |node|
      node.vm.box = "ubuntu/focal64"
      node.vm.network "private_network", ip: "192.168.56.11"
      node.vm.synced_folder ".", "/tmp/strivly"
  
      node.vm.provision "shell", inline: <<-SHELL
        # worker script
        cd /tmp/strivly
        chmod +x worker.sh
        ./worker.sh &
      SHELL
    end
  
    # manager node
    config.vm.define "manager" do |node|
      node.vm.box = "ubuntu/focal64"
      node.vm.network "private_network", ip: "192.168.56.12"
      node.vm.synced_folder ".", "/tmp/strivly"
  
      node.vm.provision "shell", inline: <<-SHELL
        # manager script
        cd /tmp/strivly
        chmod +x manager.sh
        ./manager.sh
      SHELL
    end
  end
  