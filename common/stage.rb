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
