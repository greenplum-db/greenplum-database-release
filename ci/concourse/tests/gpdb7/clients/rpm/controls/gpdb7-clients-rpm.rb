# encoding: utf-8
# GP-Releng

title 'Greenplum-db Clients RPM integration testing'

gpdb_clients_path = ENV['GPDB_CLIENTS_PATH']
gpdb_clients_version = ENV['GPDB_CLIENTS_VERSION']
gpdb_clients_arch = ENV['GPDB_CLIENTS_ARCH']

def rpm_query(field_name, rpm_full_path)
  "rpm --query --queryformat '%{#{field_name}}' --package #{rpm_full_path}"
end

rpm_full_path = "#{gpdb_clients_path}/greenplum-db-clients-#{gpdb_clients_version}-#{gpdb_clients_arch}-x86_64.rpm"
rpm_gpdb_version = `#{rpm_query("Version", rpm_full_path)}`
rpm_gpdb_name = 'greenplum-db-clients'

# for RPMs `-` is an invalid character for the version string
# when the RPM was built, any `-` was converted to `_`
gpdb_version = rpm_gpdb_version.sub("_", "-") if rpm_gpdb_version != nil

control 'Category:clients-rpm_metadata' do

    title 'rpm metadata is valid'
    desc 'The rpm metadata is valid per product requirements'

    # Note: many of the rpm metadata fields (tags) are required when building.
    # Therefore this is no need to test if they aren't specified (they have to
    # be).

    describe command("rpm -qip #{gpdb_clients_path}/greenplum-db-clients-#{gpdb_clients_version}-#{gpdb_clients_arch}-x86_64.rpm | grep Group") do
      # If group is not specified, it's default is "unspecified"
      # starting w/ GPDB6, we discontinued defining the group
      # https://fedoraproject.org/wiki/RPMGroups#DEPRECATION_ALERT
      its('stdout') { should match /Group       : Unspecified/ }
    end

    describe command("rpm -qip #{gpdb_clients_path}/greenplum-db-clients-#{gpdb_clients_version}-#{gpdb_clients_arch}-x86_64.rpm | grep URL") do
      # If URL is not specified, the field will be ommited
      its('stdout') { should match /URL/ }
    end

    # Test specified URL is reachable
    describe command("curl -s --head $(rpm -qip #{gpdb_clients_path}/greenplum-db-clients-#{gpdb_clients_version}-#{gpdb_clients_arch}-x86_64.rpm | grep URL | awk \"{print $3\"}) | head -n 1 | grep 'HTTP/[1-2].* [23]..'") do
      # If URL is not specified, the field will be ommited
      its('stdout') { should match /200/ }
    end

end

control 'Category:clients-rpm-functionality' do

  impact 1.0
  title 'GPDB Clients RPM Functionality Testing'
  desc 'Test functionality of greenplum-db-clients'

  prefix="/usr/local"

  if os.redhat?
    # Should not already be installed
    describe command('yum -yq remove greenplum-db-clients; yum -q list installed greenplum-db-clients') do
      its('exit_status') { should eq 1 }
    end

    # Should be installable
    describe command("yum install -y #{gpdb_clients_path}/greenplum-db-clients-#{gpdb_clients_version}-#{gpdb_clients_arch}-x86_64.rpm") do
        its('exit_status') { should eq 0 }
    end

    # Should report installed
    describe command('sleep 5;yum -q list installed greenplum-db-clients') do
      its('stdout') { should match /Installed Packages/ }
      its('stdout') { should match /greenplum-db-clients*/ }
      its('exit_status') { should eq 0 }
    end

    # Should create symlink
    describe file('/usr/local/greenplum-db-clients') do
      it { should be_linked_to "/usr/local/greenplum-db-clients-#{gpdb_clients_version}" }
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
  elsif os.suse?

    prefix="/usr/local"

    # Should not report installed
    describe command('zypper search greenplum-db-clients') do
      its('exit_status') { should eq 104 }
    end

    # Should be installable
    describe command("zypper --non-interactive --no-gpg-checks install #{rpm_full_path}") do
      its('exit_status') { should eq 0 }
    end

    # Should report installed
    describe command('zypper search greenplum-db-clients') do
      its('stdout') { should match (/greenplum-db-clients*/) }
      its('exit_status') { should eq 0 }
    end

    # Should create symlink
    describe file('/usr/local/greenplum-db-clients') do
      it { should be_linked_to "/usr/local/greenplum-db-clients-#{gpdb_clients_version}" }
    end
    # should generate bytecode
    describe file("/usr/local/greenplum-db-clients/ext/python/lib/python2.7/cmd.pyc") do
      it { should exist}
    end

    # Should be uninstallable
    describe command('zypper --non-interactive remove greenplum-db-clients') do
      its('exit_status') { should eq 0 }
    end

    # Should report uninstalled
    describe command('sleep 5; zypper search greenplum-db-clients') do
      its('exit_status') { should eq 104 }
    end

    # Should remove link created in %post scriptlet
    describe file("#{prefix}/greenplum-db-clients") do
      it { should_not exist }
    end
  # This will catch the Photon case
  # https://docs.chef.io/inspec/resources/os/#osfamily-names
  elsif os.linux?

    prefix="/usr/local"

    # Should not already be installed
    describe command('rpm --query greenplum-db-clients') do
      its('exit_status') { should eq 1 }
    end

    describe command("rpm --install #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
    end

    # Should report installed
    describe command('rpm --query greenplum-db-clients') do
      its('stdout') { should match /greenplum-db-clients*/ }
      its('exit_status') { should eq 0 }
    end

    # Should create symlink
    describe file('/usr/local/greenplum-db-clients') do
      it { should be_linked_to "/usr/local/greenplum-db-clients-#{gpdb_clients_version}" }
    end

    # Should be uninstallable
    describe command('rpm --erase greenplum-db-clients') do
      its('exit_status') { should eq 0 }
    end

    # Should report uninstalled
    describe command('sleep 5; rpm --query greenplum-db-clients') do
      its('exit_status') { should eq 1 }
    end
    # Should remove link created in %post scriptlet
    describe file("#{prefix}/greenplum-db-clients") do
      it { should_not exist }
    end
  end
end

control 'Category:clients-rpm-keep-symlink' do
  describe command("rpm --install #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  describe file("/usr/local/greenplum-db-clients") do
    it { should be_linked_to "/usr/local/greenplum-db-clients-#{gpdb_clients_version}" }
  end

  describe command("ln -sf --no-target-directory /usr/local/new-greenplum-clients-version /usr/local/greenplum-db-clients") do
    its('exit_status') { should eq 0 }
  end

  describe command('rpm --erase greenplum-db-clients') do
    its('exit_status') { should eq 0 }
  end

  # when the rpm is uninstalled, it should have detected that
  # `/usr/local/greenplum-db` was not pointed at the versioned greenplum
  # directory and left it in-place we use shallow_link_path here because the
  # actual target does not exist
  describe file("/usr/local/greenplum-db-clients") do
    its('type') { should eq :symlink }
    its('shallow_link_path') { should eq "/usr/local/new-greenplum-clients-version"}
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
    describe command("rpm --prefix=#{prefix} -ivh #{gpdb_clients_path}/greenplum-db-clients-#{gpdb_clients_version}-#{gpdb_clients_arch}-x86_64.rpm") do
      its('exit_status') { should eq 0 }
    end

    # Should create the proper symbolic link
    describe file("#{prefix}/greenplum-db-clients") do
      it { should be_linked_to "#{prefix}/greenplum-db-clients-#{gpdb_clients_version}" }
    end

    # Prefix should be reflected in greenplum_clients_path.sh
    describe file("#{prefix}/greenplum-db-clients/greenplum_clients_path.sh") do
      its('content') { should match /export GPHOME_CLIENTS/ }
    end

    describe command("source #{prefix}/greenplum-db-clients/greenplum_clients_path.sh; echo $GPHOME_CLIENTS") do
        its('exit_status') { should eq 0 }
        its('stdout') { should match "#{prefix}\/greenplum-db-clients-#{gpdb_clients_version.split('+').first}" }
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
