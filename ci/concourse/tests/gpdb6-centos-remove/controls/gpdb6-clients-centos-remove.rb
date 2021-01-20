# encoding: utf-8
# GP-RelEng

title 'Greenplum-db Clients RPM integration testing'

gpdb_clients_rpm_path = ENV['GPDB_CLIENTS_RPM_PATH']
gpdb_clients_version = ENV['GPDB_CLIENTS_VERSION']
gpdb_clients_rpm_arch = ENV['GPDB_CLIENTS_RPM_ARCH']

control 'Category:clients-uninstalls_on_centos' do

  impact 1.0
  title 'RPM uninstalls on centos'
  desc 'The RPM uninstalls completels on centos with yum'

  prefix="/usr/local"

  # Should report installed
  describe command('yum -q list installed greenplum-db-clients') do
    its('stdout') { should match /Installed Packages/ }
    its('stdout') { should match /greenplum-db-clients*/ }
    its('exit_status') { should eq 0 }
  end

  # Should be uninstallable
  describe command('yum remove -y greenplum-db-clients') do
    its('exit_status') { should eq 0 }
  end

  # Should report uninstalled
  describe command('sleep 5; yum -q list installed greenplum-db-clients') do
    its('exit_status') { should eq 1 }
  end

  # Should remove link created in %post scriptlet
  describe file("#{prefix}/greenplum-db-clients") do
    it { should_not exist }
  end

end
