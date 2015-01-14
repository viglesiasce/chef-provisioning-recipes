machine_batch 'Destroy nodes' do
  self.run_context.run_config.all_servers.each do |machine_name|
    machine machine_name do
      converge false
    end
  end
  action :destroy
end

%W(staging-#{self.run_context.run_config.deployment_name} prod-#{self.run_context.run_config.deployment_name}).each do |environment|
  chef_environment environment do
    action :delete
  end
end
fog_key_pair self.run_context.run_config.deployment_name do
  action :delete
end
