Chef::Log.info("Run config: #{self.run_context.run_config.all_servers}")
deployment_options = { 'java' => { 'jdk_version' => '7',
                                   'install_flavor' => 'openjdk'},
                       'cassandra' => { 'version' => '2.0.10',
                                        'release' => '1',
                                        'cluster_name' => self.run_context.run_config.deployment_name,
                                        'service_action' => 'enable',
                                        'metrics_reporter' => {'config' => {}}},
                       'consul' => {'bind_interface' => 'eth0',
                                    'domain' => 'paas.home',
                                    'advertise_interface' => 'eth0',
                                    'client_interface' => 'eth0',
                                    'serve_ui' => true,
                                    'service_mode' => 'cluster',
                                    'bootstrap_expect' => (self.run_context.run_config.machine_count - 1).to_s,
                                    'ports' => {'dns' => 53}
                                    }
                      }
service_json = '{"service": {
                  "name": "cassandra",
                  "tags": ["db"],
                  "port": 9160,
                  "check": {
                      "script": "nodetool ring 2>&1",
                      "interval": "30s"
                    }
                  }
                }'
  chef_environment self.run_context.run_config.production_env do
    default_attributes lazy {
       staging_nodes = search(:node, "chef_environment:#{self.run_context.run_config.staging_env}").map {|node| node[:ipaddress]}
       Chef::Log.info("Staging nodes: #{staging_nodes}")
       Chef::Log.info("Prod nodes: #{self.run_context.run_config.prod_nodes}")
       seeds = Set.new(staging_nodes + self.run_context.run_config.prod_nodes).to_a
       prod_options = deployment_options
       prod_options['consul']['servers'] = seeds
       prod_options['cassandra']['seeds'] = seeds.join(',')
       prod_options['cassandra']['service_action'] = %w(enable start)
       prod_options
      }
  end
  with_chef_environment self.run_context.run_config.production_env
  machine_batch 'Converge recipes' do
    self.run_context.run_config.all_servers.each do |machine_name|
      machine machine_name do
        file '/etc/consul.d/cassandra.json' => {:content => service_json}
        recipe 'cassandra'
        recipe 'consul'
        recipe 'consul::ui'
        converge true
      end
    end
  end
