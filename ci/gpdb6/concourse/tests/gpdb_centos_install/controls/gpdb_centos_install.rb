# encoding: utf-8
# Pa-Toolsmiths

title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']
rpm_gpdb_version = ENV['RPM_GPDB_VERSION']
gpdb_version = rpm_gpdb_version.sub("_", "-") if rpm_gpdb_version != nil
rpm_full_path = "#{gpdb_rpm_path}/greenplum-db-#{gpdb_rpm_arch}-x86_64.rpm"
rpm_gpdb_name = 'greenplum-db-6'

control 'Category:server-installs_on_centos' do

  impact 1.0
  title 'RPM installs on centos'
  desc 'The RPM can be installed on centos with yum'

  # Should not already be installed
  describe command("yum -y --quiet remove #{rpm_gpdb_name}; yum --quiet list installed #{rpm_gpdb_name}") do
    its('exit_status') { should eq 1 }
  end

  describe command("yum install -y #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  describe command("yum reinstall -y #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  # Should report installed
  describe command("sleep 5;yum -q list installed #{rpm_gpdb_name}") do
    its('stdout') { should match /Installed Packages/ }
    its('stdout') { should match /greenplum-db-6*/ }
    its('exit_status') { should eq 0 }
  end

end
