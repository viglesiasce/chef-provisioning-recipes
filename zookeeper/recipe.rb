Chef::Log.info("Run config: #{self.run_context.run_config.all_servers}")
deployment_options = { 'java' => { 'jdk_version' => '7',
                                   'install_flavor' => 'openjdk'},
                        'exhibitor' => {'snapshot_dir' => '/var/lib/zookeeper',
                                        'transaction_dir' => '/var/lib/zookeeper'}
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
        prod_options['exhibitor']['config'] = {'servers_spec' => exhibitor_spec.join(',')}
        Chef::Log.info("Exhibitor server spec: #{exhibitor_spec.join(',')}")
        prod_options
      }
  end
  with_chef_environment self.run_context.run_config.production_env
  machine_batch 'Move to prod' do
    self.run_context.run_config.all_servers.each do |machine_name|
      machine machine_name do
        recipe 'exhibitor'
        recipe 'exhibitor::service'
        converge true
      end
    end
  end
