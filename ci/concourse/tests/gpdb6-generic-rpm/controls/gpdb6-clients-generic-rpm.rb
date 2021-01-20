# encoding: utf-8
# GP-RelEng

title 'Greenplum-db Clients RPM integration testing'

gpdb_clients_rpm_path = ENV['GPDB_CLIENTS_RPM_PATH']
gpdb_clients_rpm_arch = ENV['GPDB_CLIENTS_RPM_ARCH']
gpdb_clients_version = ENV['GPDB_CLIENTS_VERSION']

control 'Category:clients-rpm_metadata' do

  title 'rpm metadata is valid'
  desc 'The rpm metadata is valid per product requirements'

  # Note: many of the rpm metadata fields (tags) are required when building.
  # Therefore this is no need to test if they aren't specified (they have to
  # be).

  describe command("rpm -qip #{gpdb_clients_rpm_path}/greenplum-db-clients-*-#{gpdb_clients_rpm_arch}-x86_64.rpm | grep Group") do
    # If group is not specified, it's default is "unspecified"
    # starting w/ GPDB6, we discontinued defining the group
    # https://fedoraproject.org/wiki/RPMGroups#DEPRECATION_ALERT
    its('stdout') { should match /Group       : Unspecified/ }
  end

  describe command("rpm -qip #{gpdb_clients_rpm_path}/greenplum-db-clients-*-#{gpdb_clients_rpm_arch}-x86_64.rpm | grep URL") do
    # If URL is not specified, the field will be ommited
    its('stdout') { should match /URL/ }
  end

  # Test specified URL is reachable
  describe command("curl -s --head $(rpm -qip #{gpdb_clients_rpm_path}/greenplum-db-clients-*-#{gpdb_clients_rpm_arch}-x86_64.rpm | grep URL | awk \"{print $3\"}) | head -n 1 | grep 'HTTP/1.[01] [23]..'") do
    # If URL is not specified, the field will be ommited
    its('stdout') { should match /HTTP\/1.1 200 OK/ }
  end

end

control 'Category:clients-rpm_installable' do

  title 'rpm is installable with rpm'
  desc 'The rpm can be installed and then uninstalled with the rpm utility'

  # Should not already be installed
  describe command('rpm -q greenplum-db-clients') do
    its('stdout') { should match /package greenplum-db-clients is not installed/ }
  end

  # Should be installable
  describe command("yum install -y #{gpdb_clients_rpm_path}/greenplum-db-clients-*-#{gpdb_clients_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  # Should create the proper symbolic link
  describe file("/usr/local/greenplum-db-clients") do
    it { should be_linked_to "/usr/local/greenplum-db-clients-#{gpdb_clients_version}" }
  end

  # Should report installed
  describe command('sleep 1; rpm -q greenplum-db-clients') do
    its('stdout') { should match /greenplum-db-clients-.*/ }
  end

  # Should be uninstallable
  describe command('rpm -e greenplum-db-clients') do
    its('exit_status') { should eq 0 }
  end

  # Should report uninstalled
  describe command('rpm -q greenplum-db-clients') do
    its('stdout') { should match /package greenplum-db-clients is not installed/ }
  end

end

control 'Category:clients-rpm_relocateable' do

  title 'RPM is relocateable'
  desc 'The RPM should allow specifying an installation PREFIX and handle accordingly'

  prefix="/opt"

  # Should not already be installed
  describe command('rpm -q greenplum-db-clients') do
    its('stdout') { should match /package greenplum-db-clients is not installed/ }
  end

  # Should be installable at a user given prefix (/opt as a test example)
  describe command("rpm --prefix=#{prefix} -ivh #{gpdb_clients_rpm_path}/greenplum-db-clients-*-#{gpdb_clients_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  # Should create the proper symbolic link
  describe file("#{prefix}/greenplum-db-clients") do
    it { should be_linked_to "#{prefix}/greenplum-db-clients-#{gpdb_clients_version}" }
  end

  # Prefix should be reflected in greenplum_clients_path.sh
  describe file("#{prefix}/greenplum-db-clients/greenplum_clients_path.sh") do
    its('content') { should match /GPHOME_CLIENTS=#{prefix}\/greenplum-db-clients-.*/ }
    its('content') { should match /export GPHOME_CLIENTS/ }
  end

  # Should report installed
  describe command('rpm -q greenplum-db-clients') do
    its('stdout') { should match /greenplum-db-clients-*/ }
  end

  # Should be uninstallable
  describe command('rpm -e greenplum-db-clients') do
    its('exit_status') { should eq 0 }
  end

  # Should report uninstalled
  describe command('rpm -q greenplum-db-clients') do
    its('stdout') { should match /package greenplum-db-clients is not installed/ }
  end

end

