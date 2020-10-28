# encoding: utf-8
# Pa-Toolsmiths

title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_version = ENV['GPDB_VERSION']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']

control 'uninstalls_on_centos' do

  impact 1.0
  title 'RPM uninstalls on centos'
  desc 'The RPM uninstalls completels on centos with yum'

  prefix="/usr/local"

  # Should report installed
  describe command('yum -q list installed greenplum-db-5') do
    its('stdout') { should match /Installed Packages/ }
    its('stdout') { should match /greenplum-db*/ }
    its('exit_status') { should eq 0 }
  end

  # Should be uninstallable
  describe command('yum remove -y greenplum-db-5') do
    its('exit_status') { should eq 0 }
  end

  # Should report uninstalled
  describe command('sleep 5; yum -q list installed greenplum-db-5') do
    its('exit_status') { should eq 1 }
  end

  # Should remove link created in %post scriptlet
  describe file("#{prefix}/greenplum-db") do
    it { should_not exist }
  end

end
