Vagrant.configure("2") do |config|
  # Base box from Vagrant Cloud
  config.vm.box = "ubuntu/focal64"
  config.vm.hostname = "controller"
  config.vm.network "private_network", ip: "192.168.56.10"

  config.vm.provision "shell", inline: <<-SHELL
    echo "--- Setting up Ansible controller ---"
    apt-get update -y
    apt-get install -y python3 python3-pip ansible openssh-client

    # Generate SSH key for Ansible
    if [ ! -f /home/vagrant/.ssh/id_rsa ]; then
      sudo -u vagrant ssh-keygen -t rsa -b 2048 -N "" -f /home/vagrant/.ssh/id_rsa
    fi

    # Create inventory file
    cat <<EOF > /home/vagrant/hosts
    [web]
    192.168.56.11
    [db]
    192.168.56.12
    EOF

    chown vagrant:vagrant /home/vagrant/hosts
    echo "export ANSIBLE_INVENTORY=/home/vagrant/hosts" >> /home/vagrant/.bashrc
  SHELL
end
