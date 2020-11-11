# encoding: utf-8
# Pa-Toolsmiths

title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']
gpdb_version = ENV['GPDB_VERSION']

control 'rpm_metadata' do

  title 'rpm metadata is valid'
  desc 'The rpm metadata is valid per product requirements'

  # Note: many of the rpm metadata fields (tags) are required when building.
  # Therefore this is no need to test if they aren't specified (they have to
  # be).

  describe command("rpm --query --info --package #{gpdb_rpm_path}/greenplum-db-*-#{gpdb_rpm_arch}-x86_64.rpm | grep Group") do
    # If group is not specified, it's default is "unspecified"
    its('stdout') { should_not match /Group       : Unspecified/ }
  end

  describe command("rpm --query --info --package #{gpdb_rpm_path}/greenplum-db-*-#{gpdb_rpm_arch}-x86_64.rpm | grep URL") do
    # If URL is not specified, the field will be ommited
    its('stdout') { should match /URL/ }
  end

  # Test specified URL is reachable
  describe command("curl --silent --head $(rpm --query --info --package #{gpdb_rpm_path}/greenplum-db-*-#{gpdb_rpm_arch}-x86_64.rpm | grep URL | awk \"{print $3\"}) | head -n 1 | grep 'HTTP/1.[01] [23]..'") do
    before do
      # sles11 doesn't support the TLS version necessary to connect to *.docs.pivotal.io
      skip if gpdb_rpm_arch == "sles11"
    end
    # If URL is not specified, the field will be ommited
    its('stdout') { should match /HTTP\/1.1 200 OK/ }
  end

end

control 'rpm_installable' do

  title 'rpm is installable with rpm'
  desc 'The rpm can be installed and then uninstalled with the rpm utility'

  describe command("rpm --install --verbose --hash #{gpdb_rpm_path}/greenplum-db-*-#{gpdb_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  describe file("/usr/local/greenplum-db") do
    it { should be_linked_to "/usr/local/greenplum-db-#{gpdb_version}" }
  end

  describe command('rpm --erase greenplum-db-5') do
    its('exit_status') { should eq 0 }
  end

  describe file("/usr/local/greenplum-db") do
    it { should_not exist }
  end

end

control 'rpm_relocateable' do

  title 'RPM is relocateable'
  desc 'The RPM should allow specifying an installation PREFIX and handle accordingly'

  prefix="/opt"

  describe command("rpm --prefix=#{prefix} --install --verbose --hash #{gpdb_rpm_path}/greenplum-db-*-#{gpdb_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  describe file("#{prefix}/greenplum-db") do
    it { should be_linked_to "#{prefix}/greenplum-db-#{gpdb_version}" }
  end

  describe file("#{prefix}/greenplum-db/greenplum_path.sh") do
    its('content') { should match /GPHOME=#{prefix}\/greenplum-db-.*/ }
    its('content') { should match /export GPHOME/ }
  end

  describe command('rpm --erase greenplum-db-5') do
    its('exit_status') { should eq 0 }
  end

end

control 'rpm_no_deps' do

  title 'RPM has no dependencies'
  desc 'The RPM should not have any dependencies beyond the standard for all RPMs'

  # All RPM's will have dependencies on rpmlib and /bin/sh, therefore those are excluded
  describe command("rpm --query --package --requires #{gpdb_rpm_path}/greenplum-db-*-#{gpdb_rpm_arch}-x86_64.rpm | grep --invert-match rpmlib | grep --invert-match /bin/sh") do
    its('exit_status') { should eq 1 }
  end

end
