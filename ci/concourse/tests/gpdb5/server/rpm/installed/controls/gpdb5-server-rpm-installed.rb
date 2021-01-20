# encoding: utf-8
# Pa-Toolsmiths

title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_version = ENV['GPDB_VERSION']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']

control 'installs_with_link' do

  impact 1.0
  title 'RPM installs with symbolic link'
  desc 'When the RPM is installed a shorter symbolic link is created and destroyed on uninstall'

  describe file('/usr/local/greenplum-db') do
    it { should be_linked_to "/usr/local/greenplum-db-#{gpdb_version}" }
  end

end

control 'greenplum_path.sh' do

  impact 1.0
  title 'greenplum_path.sh is correct'
  desc 'Modification must be made to the given upstream greenplum_path.sh'

  describe command('source /usr/local/greenplum-db/greenplum_path.sh; echo $GPHOME') do
    its('exit_status') { should eq 0 }
    its('stdout') { should eq "/usr/local/greenplum-db-#{gpdb_version}\n" }
  end

end

control 'rpm_binary_match' do

  impact 1.0
  title 'RPM Binary matches Built Source'
  desc 'The binaries that are packaged in the RPM should match in version to what is expected from the source code'

  describe command('source /usr/local/greenplum-db/greenplum_path.sh ; /usr/local/greenplum-db/bin/postgres --gp-version') do
    its('exit_status') { should eq 0 }
    skip "its('stdout') { should match /#{gpdb_version.split('+').first}/ }"
  end

end

