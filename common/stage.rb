require 'chef/provisioning/fog_driver/driver'

class RunConfig
  attr_accessor :name, :credentials, :machine_count, :deployment_name
  def initialize
    @name = ENV['application']
    @credentials = ENV['credentials']
    @machine_count = 3
    @deployment_name = "#{ENV['application']}-#{ENV['credentials']}"
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


with_chef_local_server :chef_repo_path => ENV['chefRepo']

with_driver 'fog:AWS', :compute_options => { :aws_access_key_id => ENV['accessKey'],
                                             :aws_secret_access_key => ENV['secretKey'],
                                             :ec2_endpoint => ENV['ec2Endpoint'],
                                             :iam_endpoint => ENV['iamEndpoint'],
                                             :region => ENV['region']
                     }

with_machine_options :ssh_username => ENV['sshUsername'], :ssh_timeout => 180, :bootstrap_options => {
                                                            :image_id => ENV['imageId'],
                                                            :flavor_id => ENV['instanceType'],
                                                            :key_name => self.run_context.run_config.deployment_name,
#                                                             :block_device_mapping => [
#                                                                 { :DeviceName => '/dev/sda', 'Ebs.VolumeSize' => 20 }],
#                                                             :user_data => 'Content-Type: multipart/mixed; boundary="===============5423618256409275201=="
# MIME-Version: 1.0
#
# --===============5423618256409275201==
# Content-Type: text/x-shellscript; charset="us-ascii"
# MIME-Version: 1.0
# Content-Transfer-Encoding: 7bit
# Content-Disposition: attachment; filename="script.sh"
#
# #!/bin/bash
# mkdir -p /etc/mesos-slave
# mkdir -p /etc/mesos-master
# instance_id=`curl http://169.254.169.254/latest/meta-data/instance-id`
# instance_ip=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
# echo $instance_ip > /etc/mesos-master/hostname
# echo $instance_ip > /etc/mesos-slave/hostname
# --===============5423618256409275201==
# Content-Type: text/cloud-config; charset="us-ascii"
# MIME-Version: 1.0
# Content-Transfer-Encoding: 7bit
# Content-Disposition: attachment; filename="cloud-config.txt"
#
# #cloud-config
# disable_root: false
# apt_mirror: http://us.archive.ubuntu.com/ubuntu/
# byobu_by_default: system
# resize_rootfs: True
# mounts:
# - [ swap, null ]
#
# --===============5423618256409275201==--
# '
                                                        }

fog_key_pair self.run_context.run_config.deployment_name do
  allow_overwrite true
end

Chef::Log.info("All servers are:#{self.run_context.run_config.all_servers}")
Chef::Log.info("New servers are:#{self.run_context.run_config.new_servers}")

chef_environment self.run_context.run_config.staging_env
with_chef_environment self.run_context.run_config.staging_env
new_servers = self.run_context.run_config.new_servers
machine_batch 'Stage nodes' do
  new_servers.each do |machine_name|
    machine machine_name do
      action :ready
      converge false
    end
  end
end
