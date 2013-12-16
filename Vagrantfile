VAGRANTFILE_API_VERSION = "2"
VM_BOX_URL = "https://s3.amazonaws.com/gsc-vagrant-boxes/ubuntu-12.04-omnibus-chef.box"

HOST_SRC  = File.dirname(File.expand_path __FILE__)
LOCAL_SRC = '/home/vagrant/hammerspace'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |master_config|
  master_config.vm.define 'hammerspace-development' do |config|
    # base image is our standard airbase -- ubuntu 12.04
    config.vm.box = "airbase"
    config.vm.box_url = VM_BOX_URL

    config.vm.synced_folder HOST_SRC, LOCAL_SRC

    config.vm.provider "virtualbox" do |v|
      v.customize ['modifyvm', :id,
        '--cpus', 2,
        '--memory', 512
      ]
    end

    config.vm.provision :chef_solo do |chef|
      chef.cookbooks_path = '.chef/cookbooks'
      chef.roles_path     = '.chef/roles'
      chef.data_bags_path = '.chef/data_bags'

      chef.add_role('hammerspace-development')
    end
  end
end
