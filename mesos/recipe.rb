deployment_options = { :java => {:jdk_version => '7',
                                 :install_flavor => 'openjdk'},
                       :docker => {:graph => '/mnt/docker'}
}

chef_environment self.run_context.run_config.production_env do
  default_attributes lazy {
     staging_nodes = search(:node, "chef_environment:#{self.run_context.run_config.staging_env}").map {|node| node[:ipaddress]}
     Chef::Log.info("Staging nodes: #{staging_nodes}")
     Chef::Log.info("Prod nodes: #{self.run_context.run_config.prod_nodes}")
     seeds = Set.new(staging_nodes + self.run_context.run_config.prod_nodes).to_a
     prod_options = deployment_options
     exhibitor_spec = []
     node_count = 1
     seeds.each do |server_ip|
       exhibitor_spec << "#{node_count}:#{server_ip}"
       node_count += 1
     end
     prod_options[:exhibitor] = {:user => 'root',
                                 :snapshot_dir => '/mnt/zookeeper',
                                 :transaction_dir => '/mnt/zookeeper',
                                 :log_index_dir => '/mnt/zookeeper',
                                 :config => {:servers_spec => exhibitor_spec.join(','),
                                             :auto_manage_instances => 0
                                 },
                                 :cli => {:port => '8081'}
                                }
     zk_hosts = seeds.map {|ip| ip + ":2181"}
     zk_url = 'zk://' + zk_hosts.join(',') + '/mesos'
     Chef::Log.info("Exhibitor server spec: #{exhibitor_spec.join(',')}")
     prod_options[:mesos] = {
                              :version => '0.22.1',
                              :master => {  :flags => {
                                              :log_dir => '/mnt/mesos/log',
                                              :work_dir => '/mnt/mesos',
                                              :cluster => self.run_context.run_config.deployment_name,
                                              :zk => zk_url,
                                              :quorum => '2'
                                            }
                                          },
                              :slave =>  {  :flags => {
                                              :containerizers => 'docker,mesos',
                                              :master => zk_url,
                                              :work_dir => '/mnt/mesos',
                                              :isolation => "cgroups/cpu,cgroups/mem",
                                              :resources => "ports:[1-65535]",
                                              :executor_registration_timeout => '10mins'
                                            }
                                          }
                              }
     prod_options
    }
end
with_chef_environment self.run_context.run_config.production_env
machine_batch 'Install Dependencies' do
  self.run_context.run_config.all_servers.each do |machine_name|
    machine machine_name do
      recipe 'exhibitor'
      recipe 'exhibitor::service'
      recipe 'docker'
    end
  end
end

with_chef_environment self.run_context.run_config.production_env
machine_batch 'Setup Mesos extras' do
  self.run_context.run_config.all_servers.each do |machine_name|
    machine machine_name do
      recipe 'mesos-extras'
    end
  end
end
