# encoding: utf-8
# Pa-Toolsmiths

title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_version = ENV['GPDB_VERSION']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']

control 'uninstalls_on_sles' do

  impact 1.0
  title 'RPM uninstalls on sles'
  desc 'The RPM uninstalls completels on sles with zypper'

  prefix="/usr/local"

  # Should report installed
  describe command('zypper search greenplum-db-5') do
    its('stdout') { should match /^i | greenplum-db* / }
    its('exit_status') { should eq 0 }
  end

  # Should be uninstallable
  describe command('zypper --non-interactive remove greenplum-db-5') do
    its('exit_status') { should eq 0 }
  end

  # Should not already be installed
  describe command('zypper search greenplum-db-5') do
    its('exit_status') { should_not eq 0 }
  end

  # Should remove link created in %post scriptlet
  describe file("#{prefix}/greenplum-db") do
    it { should_not exist }
  end

end
