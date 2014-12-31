require 'chef/provisioning/fog_driver/driver'

with_chef_local_server :chef_repo_path => ENV['chefRepo']

deployment_name = "#{ENV['application']}-#{ENV['credentials']}"
total_machines = 3

with_driver 'fog:AWS', :compute_options => { :aws_access_key_id => ENV['accessKey'],
                                             :aws_secret_access_key => ENV['secretKey'],
                                             :ec2_endpoint => ENV['ec2Endpoint'],
                                             :iam_endpoint => ENV['iamEndpoint'],
                                             :region => ENV['region']
                     }

with_machine_options :ssh_username => ENV['sshUsername'], :ssh_timeout => 60, :bootstrap_options => {
    :image_id => ENV['imageId'],
    :flavor_id => ENV['instanceType'],
    :key_name => deployment_name,
}

fog_key_pair deployment_name do
  allow_overwrite true
end

deployment_options = { 'java' => { 'jdk_version' => '7',
                                   'install_flavor' => 'openjdk'},
                        'exhibitor' => {'snapshot_dir' => '/var/lib/zookeeper',
                                        'transaction_dir' => '/var/lib/zookeeper'}
                      }
staging_env = "staging-#{deployment_name}"
production_env = "prod-#{deployment_name}"
chef_environment staging_env do
  default_attributes deployment_options
end

prod_nodes =  search(:node, "chef_environment:#{production_env}").map {|node| node[:ipaddress]}
all_servers = (1..total_machines).step(1).map {|i| deployment_name + '-' + i.to_s}
new_servers = all_servers - search(:node, "chef_environment:#{production_env}").map {|node| node.name}
Chef::Log.info("All servers are:#{all_servers}")
Chef::Log.info("New servers are:#{new_servers}")
if ENV['operation'] == 'create' or not ENV['operation']
  with_chef_environment staging_env
  machine_batch 'Stage nodes' do
    new_servers.each do |machine_name|
      machine machine_name do
        action :setup
      end
    end
  end
  chef_environment production_env do
    default_attributes lazy {
        staging_nodes = search(:node, "chef_environment:#{staging_env}").map {|node| node[:ipaddress]}
        Chef::Log.info("Staging nodes: #{staging_nodes}")
        Chef::Log.info("Prod nodes: #{prod_nodes}")
        seeds = Set.new(staging_nodes + prod_nodes).to_a
        prod_options = deployment_options
        exhibitor_spec = []
        node_count = 1
        seeds.each do |server_ip|
          exhibitor_spec << "#{node_count}:#{server_ip}"
          node_count += 1
        end
        prod_options['exhibitor']['config'] = {'servers_spec' => exhibitor_spec.join(',')}
        Chef::Log.info("Exhibitor server spec: #{exhibitor_spec.join(',')}")
        prod_options
      }
  end
  with_chef_environment production_env
  machine_batch 'Move to prod' do
    all_servers.each do |machine_name|
      machine machine_name do
        recipe 'exhibitor'
        recipe 'exhibitor::service'
        converge true
      end
    end
  end
elsif ENV['operation'] == 'destroy'
  machine_batch 'Destroy all nodes' do
    action :destroy
    machines all_servers
  end
  [staging_env, production_env].each do |environment|
    chef_environment environment do
      action :delete
    end
  end
end
