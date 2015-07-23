#
# Cookbook Name:: mesos-extras
# Recipe:: default
#
# Copyright (c) 2015 The Authors, All Rights Reserved.
env_hosts = search(:node, "chef_environment:#{node.chef_environment}")
zookeeper_hosts = env_hosts.map {|node| node[:ipaddress] + ':2181'}
zookeeper_url = 'zk://' + zookeeper_hosts.join(",")

node.override[:mesos][:master][:flags][:hostname] = node['ec2']['public_hostname']
node.override[:mesos][:slave][:flags][:hostname] = node['ec2']['public_hostname']
node.save

include_recipe 'mesos::install'
include_recipe 'mesos::master'
include_recipe 'mesos::slave'

package 'marathon'
service 'marathon' do
  action [:start, :enable]
end
directory '/etc/marathon'
directory '/etc/marathon/conf'
file '/etc/marathon/conf/hostname' do
  content node['ec2']['public_hostname']
  notifies :restart, 'service[marathon]', :immediately
end
file '/etc/marathon/conf/master' do
  content zookeeper_url + '/mesos'
  notifies :restart, 'service[marathon]', :immediately
end
file '/etc/marathon/conf/zk' do
  content zookeeper_url + '/marathon'
  notifies :restart, 'service[marathon]', :immediately
end


package 'chronos'

package 'wget'
execute 'wget -O /root/mesos-dns http://mesos-extras.s3.amazonaws.com/mesos-dns' do
  creates '/root/mesos-dns'
end

execute 'chmod +x /root/mesos-dns'

mesos_hosts = env_hosts.map {|node| '"' + node[:ipaddress] + ':5050"'}
dns_server = `cat /etc/resolv.conf | grep -i nameserver | tail -n1 | cut -d ' ' -f2`.strip
template "/root/config.json" do
  source 'mesos-dns.json.erb'
  variables(
    :mesos_hosts  => mesos_hosts,
    :resolver => dns_server
  )
  mode 00644
end

# Use mesos-dns as the first resolver
execute "sed -i '1inameserver 127.0.0.1' /etc/resolv.conf" do
  not_if 'cat /etc/resolv.conf | grep 127.0.0.1'
end

directory '/root/apps'
%w{mesos-dns elasticsearch logstash kibana}.each do |app_name|
  filename = "marathon-#{app_name}.json"
  cookbook_file "/root/apps/#{filename}" do
    source filename
    mode 00644
  end
  execute "curl -X POST http://localhost:8080/v2/apps -H \"Content-type: application/json\" -d@/root/apps/#{filename}" do
    retries 12
    retry_delay 10
    not_if "curl http://localhost:8080/v2/apps | egrep '\"id\":\"/#{app_name}\"'"
  end
end
