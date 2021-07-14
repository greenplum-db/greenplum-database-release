# encoding: utf-8
# Pa-Toolsmiths

title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_version = ENV['GPDB_VERSION']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']

rpm_gpdb_name = 'greenplum-db-5'
rpm_full_path = "#{gpdb_rpm_path}/#{rpm_gpdb_name}-#{gpdb_rpm_arch}-x86_64.rpm"

control 'installs_on_sles' do

  impact 1.0
  title 'RPM installs on sles'
  desc 'The RPM can be installed on sles with zypper'

  # Should not already be installed
  describe command('zypper search greenplum-db-5') do
    its('exit_status') { should_not eq 0 }
  end

  # Should be installable
  describe command("zypper --non-interactive install #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  # Should report installed
  describe command('zypper search greenplum-db-5') do
    its('stdout') { should match (/^i | greenplum-db* /) }
    its('exit_status') { should eq 0 }
  end

end

