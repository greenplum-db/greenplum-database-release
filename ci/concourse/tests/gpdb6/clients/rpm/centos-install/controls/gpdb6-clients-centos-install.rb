# encoding: utf-8
# GP-RelEng

title 'Greenplum-db Clients RPM integration testing'

gpdb_clients_rpm_path = ENV['GPDB_CLIENTS_RPM_PATH']
gpdb_clients_version = ENV['GPDB_CLIENTS_VERSION']
gpdb_clients_rpm_arch = ENV['GPDB_CLIENTS_RPM_ARCH']

control 'Category:clients-installs_on_centos' do

  impact 1.0
  title 'RPM installs on centos'
  desc 'The RPM can be installed on centos with yum'

  # Should not already be installed
  describe command('yum -yq remove greenplum-db-clients; yum -q list installed greenplum-db-clients') do
    its('exit_status') { should eq 1 }
  end

  # Should be installable
  describe command("yum install -y #{gpdb_clients_rpm_path}/greenplum-db-clients-#{gpdb_clients_version}-#{gpdb_clients_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  # Should report installed
  describe command('sleep 5;yum -q list installed greenplum-db-clients') do
    its('stdout') { should match /Installed Packages/ }
    its('stdout') { should match /greenplum-db-clients*/ }
    its('exit_status') { should eq 0 }
  end

end

