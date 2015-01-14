require 'chef/provisioning/fog_driver/driver'

deployment_name = "#{ENV['application']}-#{ENV['credentials']}"
all_servers = (1..3).step(1).map {|i| deployment_name + '-' + i.to_s}
with_chef_local_server :chef_repo_path => ENV['chefRepo']

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

machine_batch 'Destroy nodes' do
  all_servers.each do |machine_name|
    machine machine_name do
      converge false
    end
  end
  action :destroy
end

%W(staging-#{deployment_name} prod-#{deployment_name}).each do |environment|
  chef_environment environment do
    action :delete
  end
end
fog_key_pair deployment_name do
  action :delete
end