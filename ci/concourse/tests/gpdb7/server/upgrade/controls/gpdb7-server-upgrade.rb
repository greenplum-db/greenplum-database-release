title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']
# want to get the el6 from rhel6
gpdb_rpm_arch_string = gpdb_rpm_arch[2,4]

def rpm_query(field_name, rpm_full_path)
  "rpm --query --queryformat '%{#{field_name}}' --package #{rpm_full_path}"
end

rpm_gpdb_name = 'greenplum-db-7'
rpm_full_path = "#{gpdb_rpm_path}/#{rpm_gpdb_name}-#{gpdb_rpm_arch}-x86_64.rpm"
rpm_gpdb_version = `#{rpm_query("Version", rpm_full_path)}`


# for RPMs `-` is an invalid character for the version string
# when the RPM was built, any `-` was converted to `_`
gpdb_version = rpm_gpdb_version.sub("_", "-") if rpm_gpdb_version != nil
previous_6_version = File.read('previous-6.20.0-release/version').split('#').first if File.exist?('previous-6.20.0-release/version')

control 'Category:server-rpm_is_upgradable' do
  # previous-7.0.0-release can upgrade to current gpdb7 version rpm
    describe command("yum install -y previous-7.0.0-release/greenplum-db-7.0.0-el8-x86_64.rpm") do
      its('exit_status') { should eq 0 }
    end

    describe command("rpm --query greenplum-db-7") do
      its('stdout') { should match /greenplum-db-7-7.0.0*/ }
      its('exit_status') { should eq 0 }
    end

    describe file("/usr/local/greenplum-db") do
      it { should be_symlink }
      its('link_path') { should eq "/usr/local/greenplum-db-7.0.0" }
    end

    describe command("rpm --upgrade #{rpm_full_path}") do
      its('exit_status') { should eq 0 }
    end

    describe command("rpm --query greenplum-db-7") do
      its('stdout') { should eq "greenplum-db-7-#{rpm_gpdb_version}-1.el8.x86_64\n"}
      its('exit_status') { should eq 0 }
    end

    describe file("/usr/local/greenplum-db") do
      it { should be_symlink }
      its('link_path') { should eq "/usr/local/greenplum-db-#{gpdb_version}" }
    end

    describe command('rpm --erase greenplum-db-7') do
      its('exit_status') { should eq 0 }
    end
end

control 'RPM with GPDB 6' do
    describe command("yum install -y previous-6.20.0-release/greenplum-db-#{previous_6_version}-*-x86_64.rpm") do
      its('exit_status') { should eq 0 }
    end

    describe command("yum install -y #{rpm_full_path}") do
      its('exit_status') { should eq 0 }
    end

    # the previous gpdb version 6 package will still exist
    describe command("yum list installed greenplum-db-6") do
      its('exit_status') { should eq 0 }
    end

    # the directory belongs to package: greenplum-db will still exist if its package version equals to version 6.*
    describe file("/usr/local/greenplum-db-#{previous_6_version}") do
      it { should exist }
    end

    describe file("/usr/local/greenplum-db") do
      it { should be_symlink }
      its('link_path') { should eq "/usr/local/greenplum-db-#{previous_6_version}" }
    end

    describe file("/usr/local/greenplum-db-#{gpdb_version}") do
      it { should be_directory }
    end

    describe command("yum remove -y #{rpm_gpdb_name}") do
      its('exit_status') { should eq 0 }
    end

    describe command("yum remove -y greenplum-db") do
      its('exit_status') { should eq 0 }
    end
end
