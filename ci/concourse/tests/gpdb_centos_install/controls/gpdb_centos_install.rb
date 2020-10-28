# encoding: utf-8
# Pa-Toolsmiths

title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_version = ENV['GPDB_VERSION']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']

control 'installs_on_centos' do

  impact 1.0
  title 'RPM installs on centos'
  desc 'The RPM can be installed on centos with yum'

  # Should not already be installed
  describe command('yum -y --quiet remove greenplum-db-5; yum --quiet list installed greenplum-db-5') do
    its('exit_status') { should eq 1 }
  end

  describe command("yum install -y #{gpdb_rpm_path}/greenplum-db-#{gpdb_version}-#{gpdb_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  describe command("yum reinstall -y #{gpdb_rpm_path}/greenplum-db-#{gpdb_version}-#{gpdb_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  # Should report installed
  describe command('sleep 5;yum -q list installed greenplum-db-5') do
    its('stdout') { should match /Installed Packages/ }
    its('stdout') { should match /greenplum-db*/ }
    its('exit_status') { should eq 0 }
  end

end
