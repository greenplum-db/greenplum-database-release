# encoding: utf-8
# Pa-Toolsmiths

title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']
rpm_gpdb_version = ENV['RPM_GPDB_VERSION']
gpdb_version = rpm_gpdb_version.sub("_", "-") if rpm_gpdb_version != nil
rpm_gpdb_name = 'greenplum-db-6'
rpm_full_path = "#{gpdb_rpm_path}/#{rpm_gpdb_name}-#{gpdb_rpm_arch}-x86_64.rpm"



control 'RPM metadata' do

  title 'RPM metadata is valid'
  desc 'The RPM metadata is valid per product requirements'

  def rpm_query(field_name, rpm_full_path)
    "rpm --query --queryformat '%{#{field_name}}' --package #{rpm_full_path}"
  end

  describe command(rpm_query("Group", rpm_full_path)) do
    # If group is not specified, it's default is "unspecified"
    # starting w/ GPDB6, we discontinued defining the group
    # https://fedoraproject.org/wiki/RPMGroups#DEPRECATION_ALERT
    its('stdout') { should cmp "Unspecified" }
  end

  describe command(rpm_query("Name", rpm_full_path)) do
    its('stdout') { should cmp rpm_gpdb_name }
  end

  describe command(rpm_query("URL", rpm_full_path)) do
    its('stdout') { should cmp "https://network.pivotal.io/products/pivotal-gpdb/" }
  end

end

control 'Category:server-installs' do

  impact 1.0
  title 'RPM installs'
  desc 'The RPM can be installed'
  # Use yum on redhat, rpm otherwise
  if os.redhat?
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

  elsif os.linux?
    describe command("rpm --query #{rpm_gpdb_name}") do
    its('exit_status') { should eq 1 }
    end

    describe command("rpm --install #{rpm_full_path}") do
      its('exit_status') { should eq 0 }
    end

    # Should report installed
    describe command("sleep 5;rpm --query #{rpm_gpdb_name}") do
      its('stdout') { should match /greenplum-db-6*/ }
      its('exit_status') { should eq 0 }
      end
  end
end

control 'Category:server-installs_with_link' do

   impact 1.0
   title 'RPM installs with symbolic link'
   desc 'When the RPM is installed a shorter symbolic link is created and destroyed on uninstall'
  
   describe file('/usr/local/greenplum-db') do
     it { should be_linked_to "/usr/local/greenplum-db-#{gpdb_version}" }
   end
  
end
  
control 'Category:server-greenplum_path.sh' do
  
  impact 1.0
  title 'greenplum_path.sh is correct'
  desc 'Modification must be made to the given upstream greenplum_path.sh'

  # With default %{prefix}"
  describe command("source /usr/local/greenplum-db-#{gpdb_version}/greenplum_path.sh; echo $GPHOME") do
    its('exit_status') { should eq 0 }
    its('stdout') { should eq "/usr/local/greenplum-db-#{gpdb_version}\n" }
  end
  
end
  
control 'Category:server-rpm_binary_match' do
  
  impact 1.0
  title 'RPM Binary matches Built Source'
  desc 'The binaries that are packaged in the RPM should match in version to what is expected from the source code'

  describe command("source /usr/local/greenplum-db-#{gpdb_version}/greenplum_path.sh ; /usr/local/greenplum-db-#{gpdb_version}/bin/postgres --gp-version") do
    its('exit_status') { should eq 0 }
    skip "its('stdout') { should match /#{gpdb_version}/ }"
  end
end

control 'RPM config files' do

  title 'greenplum_path.sh is preserved if its content changed'

  # make a change to the config file: greenplum-db-6/greenplum_path.sh
  describe command("echo \"# make a change\" >> /usr/local/greenplum-db-#{gpdb_version}/greenplum_path.sh") do
    its('exit_status') { should eq 0 }
  end

  describe command("rpm --erase #{rpm_gpdb_name}") do
    its('exit_status') { should eq 0 }
  end

  # When performing uninstall(it can also be downgrade or upgrade) of the RPM package,
  # any changes to the installed greenplum-db-6/greenplum_path.sh file shall not be removed.
  describe file("/usr/local/greenplum-db-#{gpdb_version}/greenplum_path.sh.rpmsave") do
    it { should exist }
  end

  describe file("/usr/local/greenplum-db") do
    it { should_not exist }
  end

  # delete the directory /usr/local/greenplum-db-6.*.*
  describe command("rm -rf /usr/local/greenplum-db-#{gpdb_version}") do
    its('exit_status') { should eq 0 }
  end

end

control 'RPM is relocateable' do

  title 'RPM is relocateable'
  desc 'The RPM should allow specifying an installation PREFIX and handle accordingly'

  prefix="/opt"

  describe command("rpm --prefix=#{prefix} --install #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  describe file("#{prefix}/greenplum-db-#{gpdb_version}") do
    it { should be_directory }
  end

  describe file("#{prefix}/greenplum-db") do
    it { should be_symlink }
    its('link_path') { should eq "#{prefix}/greenplum-db-#{gpdb_version}" }
  end

  describe command("source #{prefix}/greenplum-db-#{gpdb_version}/greenplum_path.sh; echo $GPHOME") do
    its('exit_status') { should eq 0 }
    its('stdout') { should eq "#{prefix}/greenplum-db-#{gpdb_version}\n" }
  end

  describe command("rpm --erase #{rpm_gpdb_name}") do
    its('exit_status') { should eq 0 }
  end

  describe file("#{prefix}/greenplum-db") do
    it { should_not exist }
  end

end
