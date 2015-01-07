Chef::Log.info("Run config: #{self.run_context.run_config.all_servers}")

deployment_options = { :java => { :jdk_version => '7',
                                  :install_flavor => 'openjdk'},
                       :exhibitor => { :snapshot_dir => '/var/lib/zookeeper',
                                       :transaction_dir => '/var/lib/zookeeper'},
                       :docker => { :graph => '/mnt/docker'}
}
mesosphere_repository = '[mesosphere]
name=Mesosphere Packages for EL 6 - $basearch
baseurl=http://repos.mesosphere.io/el/6/$basearch/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mesosphere

[mesosphere-noarch]
name=Mesosphere Packages for EL 6 - noarch
baseurl=http://repos.mesosphere.io/el/6/noarch/
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mesosphere

[mesosphere-source]
name=Mesosphere Packages for EL 6 - $basearch - Source
baseurl=http://repos.mesosphere.io/el/6/SRPMS/
enabled=0
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mesosphere'
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
     prod_options[:exhibitor][:config] = {:servers_spec => exhibitor_spec.join(',')}
     prod_options[:exhibitor][:cli] = {:port => '8081'}
     zk_hosts = seeds.map {|ip| ip + ":2181"}
     zk_url = 'zk://' + zk_hosts.join(',') + '/mesos'
     Chef::Log.info("Exhibitor server spec: #{exhibitor_spec.join(',')}")
     prod_options[:mesos] = { :version => '0.21.0',
                              :type => 'mesosphere',
                              :mesosphere => { :build_version => '-1.0.centos65'},
                              :master => {  :port => '5050',
                                            :log_dir => '/var/log/mesos',
                                            :zk => zk_url,
                                            :cluster => self.run_context.run_config.deployment_name,
                                            :quorum => '2'},
                              :slave =>  {  :log_dir => '/var/log/mesos',
                                            :containerizers => 'docker,mesos',
                                            :master => zk_url,
                                            :work_dir => '/mnt/mesos',
                                            :isolation => "cgroups/cpu,cgroups/mem"}
     }
     prod_options
    }
end
with_chef_environment self.run_context.run_config.production_env
machine_batch 'Move to prod' do
  self.run_context.run_config.all_servers.each do |machine_name|
    machine machine_name do
      file '/etc/yum.repos.d/mesosphere.repo' => {:content => mesosphere_repository}
      recipe 'docker::lxc'
      recipe 'docker'
      recipe 'exhibitor'
      recipe 'exhibitor::service'
      recipe 'mesos::mesosphere'
      recipe 'mesos::master'
      recipe 'mesos::slave'
    end
  end
end
