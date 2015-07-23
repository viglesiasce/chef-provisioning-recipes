class RunConfig
  attr_accessor :name, :endpoints, :machine_count, :deployment_name
  def initialize
    @name = ENV['application']
    @endpoints = ENV['endpoints']
    @machine_count = ENV.fetch('machineCount', 3).to_i
    @deployment_name = "#{ENV['application']}-#{ENV['endpoints']}"
  end
  def staging_env
    "staging-#{self.deployment_name}"
  end
  def production_env
    "prod-#{self.deployment_name}"
  end
  def prod_nodes
    Chef::Search::Query.new.search(:node, "chef_environment:#{self.production_env}").first.map {|node| node[:ipaddress]}
  end
  def all_servers
    (1..self.machine_count).step(1).map {|i| self.deployment_name + '-' + i.to_s}
  end
  def new_servers
    self.all_servers - self.prod_nodes
  end
end

class << self.run_context
  def run_config
    RunConfig.new
  end
end

require 'chef/provisioning/fog_driver/driver'

with_chef_local_server :chef_repo_path => ENV['chefRepo']

with_driver 'fog:AWS', :compute_options => { :aws_access_key_id => ENV['accessKey'],
                                             :aws_secret_access_key => ENV['secretKey'],
                                             :ec2_endpoint => ENV['ec2Endpoint'],
                                             :iam_endpoint => ENV['iamEndpoint'],
                                             :region => ENV['region']
                     }

bootstrap_options = { :image_id => ENV['imageId'],
                      :flavor_id => ENV['instanceType'],
                      :key_name => self.run_context.run_config.deployment_name,
                      :user_data => 'Content-Type: multipart/mixed; boundary="===============5423618256409275201=="
MIME-Version: 1.0

--===============5423618256409275201==
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="script.sh"

#!/bin/bash
export hostname=`curl http://169.254.169.254/latest/meta-data/public-hostname`
--===============5423618256409275201==
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
disable_root: false
apt_mirror: http://us.archive.ubuntu.com/ubuntu/
byobu_by_default: system
apt_update: true
resize_rootfs: True

--===============5423618256409275201==--
'
}

if ENV['volumeSize']
  bootstrap_options[:block_device_mapping] = [{ :DeviceName => '/dev/sda', 'Ebs.VolumeSize' => ENV.fetch('volumeSize', 10) },
                                              { :DeviceName => '/dev/sdb', :VirtualName => 'ephemeral0' }]
end

with_machine_options :ssh_username => ENV.fetch('sshUsername', 'root'),
                     :create_timeout => ENV.fetch('createTimeout', 480),
                     :create_timeout => ENV.fetch('startTimeout', 480),
                     :ssh_timeout => ENV.fetch('sshTimeout', 480), :bootstrap_options => bootstrap_options
