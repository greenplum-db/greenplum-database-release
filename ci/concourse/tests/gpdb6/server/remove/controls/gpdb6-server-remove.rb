# encoding: utf-8
# Pa-Toolsmiths

title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']
# want to get the el6 from rhel6
gpdb_rpm_arch_string = gpdb_rpm_arch[2,4]

def rpm_query(field_name, rpm_full_path)
  "rpm --query --queryformat '%{#{field_name}}' --package #{rpm_full_path}"
end

rpm_gpdb_name = 'greenplum-db-6'
rpm_full_path = "#{gpdb_rpm_path}/#{rpm_gpdb_name}-#{gpdb_rpm_arch}-x86_64.rpm"
rpm_gpdb_version = `#{rpm_query("Version", rpm_full_path)}`


# for RPMs `-` is an invalid character for the version string
# when the RPM was built, any `-` was converted to `_`
gpdb_version = rpm_gpdb_version.sub("_", "-") if rpm_gpdb_version != nil

control 'Category:server-uninstalls' do

  impact 1.0
  title 'RPM uninstalls'
  desc 'The RPM uninstalls'

  prefix="/usr/local"

  # Should report installed
  if os.redhat?
    describe command("yum install -y #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
    end

    describe command('yum -q list installed greenplum-db-6') do
      its('stdout') { should match /Installed Packages/ }
      its('stdout') { should match /greenplum-db-6*/ }
      its('exit_status') { should eq 0 }
    end

    # Should be uninstallable
    describe command('yum remove -y greenplum-db-6') do
      its('exit_status') { should eq 0 }
    end

    # Should report uninstalled
    describe command('sleep 5; yum -q list installed greenplum-db-6') do
      its('exit_status') { should eq 1 }
    end

    # Should remove link created in %post scriptlet
    describe file("#{prefix}/greenplum-db") do
      it { should_not exist }
    end
  elsif os.linux?

    prefix="/usr/local"

    describe command("rpm --install #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
    end

    # Should report installed
    describe command('rpm --query greenplum-db-6') do
      its('stdout') { should match /greenplum-db-6*/ }
      its('exit_status') { should eq 0 }
    end
  
    # Should be uninstallable
    describe command('rpm --erase greenplum-db-6') do
      its('exit_status') { should eq 0 }
    end
  
    # Should report uninstalled
    describe command('sleep 5; rpm --query greenplum-db-6') do
      its('exit_status') { should eq 1 }
    end
    # Should remove link created in %post scriptlet
    describe file("#{prefix}/greenplum-db") do
      it { should_not exist }
    end
  end
end

control 'Category:server-symlink' do
  describe command("rpm --install #{gpdb_rpm_path}/greenplum-db-#{gpdb_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  describe file("/usr/local/greenplum-db") do
    it { should be_linked_to "/usr/local/greenplum-db-#{gpdb_version}" }
  end

  describe command("ln -sf --no-target-directory /usr/local/new-greenplum-version /usr/local/greenplum-db") do
    its('exit_status') { should eq 0 }
  end

  describe command('rpm --erase greenplum-db-6') do
    its('exit_status') { should eq 0 }
  end

  # when the rpm is uninstalled, it should have detected that
  # `/usr/local/greenplum-db` was not pointed at the versioned greenplum
  # directory and left it in-place we use shallow_link_path here because the
  # actual target does not exist
  describe file("/usr/local/greenplum-db") do
    its('type') { should eq :symlink }
    its('shallow_link_path') { should eq "/usr/local/new-greenplum-version"}
  end
end
