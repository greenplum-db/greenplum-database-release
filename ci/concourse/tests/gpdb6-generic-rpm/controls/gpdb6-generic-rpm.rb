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

rpm_full_path = "#{gpdb_rpm_path}/greenplum-db-#{gpdb_rpm_arch}-x86_64.rpm"
rpm_gpdb_version = `#{rpm_query("Version", rpm_full_path)}`
rpm_gpdb_name = 'greenplum-db-6'

# for RPMs `-` is an invalid character for the version string
# when the RPM was built, any `-` was converted to `_`
gpdb_version = rpm_gpdb_version.sub("_", "-") if rpm_gpdb_version != nil
previous_6_version = File.read('previous-6-release/version').split('#').first if File.exist?('previous-6-release/version')
previous_5_version = File.read('previous-5-release/version').split('#').first if File.exist?('previous-5-release/version')

control 'Category:server-rpm_metadata' do

  title 'rpm metadata is valid'
  desc 'The rpm metadata is valid per product requirements'

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

  # Test specified URL is reachable
  describe command("curl --silent --head $(rpm --query --info --package #{rpm_full_path} | grep URL | awk \"{print $3\"}) | head -n 1 | grep 'HTTP/1.[01] [23]..'") do
    # If URL is not specified, the field will be ommited
    its('stdout') { should match /HTTP\/1.1 200 OK/ }
  end

end

control 'Category:server-rpm_installable' do

  title 'rpm is installable with rpm'
  desc 'The rpm can be installed and then uninstalled with the rpm utility'

  describe command("yum install -y #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  describe file("/usr/local/greenplum-db") do
    it { should be_symlink }
    it { should be_linked_to "/usr/local/greenplum-db-#{gpdb_version}"}
  end

  describe command("yum remove -y #{rpm_gpdb_name}") do
    its('exit_status') { should eq 0 }
  end

  describe file("/usr/local/greenplum-db-#{gpdb_version}/greenplum_path.sh.rpmsave") do
    it { should_not exist }
  end

  describe file("/usr/local/greenplum-db") do
    it { should_not exist }
  end

end

control 'Category:server-rpm_config_file' do

  title 'greenplum_path.sh is preserved if its content changed'

  describe command("yum install -y #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  # make a change to the config file: greenplum-db-6/greenplum_path.sh
  describe command("echo \"# make a change\" >> /usr/local/greenplum-db-#{gpdb_version}/greenplum_path.sh") do
    its('exit_status') { should eq 0 }
  end

  describe command("yum remove -y #{rpm_gpdb_name}") do
    its('exit_status') { should eq 0 }
  end

  # When performing uninstall(it can also be downgrade or upgrade) of the RPM package,
  # any changes to the installed greenplum-db-6/greenplum_path.sh file shall be saved.
  describe file("/usr/local/greenplum-db-#{gpdb_version}/greenplum_path.sh.rpmsave") do
    its('content') { should match /.*# make a change.*/ }
  end

  describe file("/usr/local/greenplum-db") do
    it { should_not exist }
  end

  # delete the directory /usr/local/greenplum-db-6.*.*
  describe command("rm -rf /usr/local/greenplum-db-#{gpdb_version}") do
    its('exit_status') { should eq 0 }
  end

end

control 'Category:server-rpm_obsoletes_old_6_rpm' do

  title 'when both greenplum-db version 6.2.1 and greenplum-db-6 are installed.'

  describe command("yum install -y previous-6-release/greenplum-db-#{previous_6_version}-#{gpdb_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  describe command("yum install -y #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  # the previous gpdb version 6 package will be removed
  describe command("yum list installed greenplum-db") do
    its('exit_status') { should eq 1 }
  end

  # the directory belongs to package: greenplum-db will be removed if its package version equals to version 6.*
  describe file("/usr/local/greenplum-db-#{previous_6_version}") do
    it { should_not exist }
  end

  # the link belongs to package: greenplum-db will be removed if its package version equals to version 6.*
  # so the link belongs to previous gpdb version 6 pacakge will still exist
  describe file("/usr/local/greenplum-db") do
    it { should be_symlink }
    its('link_path') { should eq "/usr/local/greenplum-db-#{gpdb_version}" }
  end

  describe file("/usr/local/greenplum-db-#{gpdb_version}") do
    it { should be_directory }
  end

  describe command("yum remove -y #{rpm_gpdb_name}") do
    its('exit_status') { should eq 0 }
  end

end

control 'Category:server-rpm_not_obsoletes_old_5_rpm' do

  title 'when both greenplum-db version 5.2.1 and greenplum-db-6 are installed.'

  describe command("yum install -y previous-5-release/greenplum-db-#{previous_5_version}-#{gpdb_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  describe command("yum install -y #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  # the previous gpdb version 5 package will still exist
  describe command("yum list installed greenplum-db") do
    its('exit_status') { should eq 0 }
  end

  # the directory belongs to package: greenplum-db will still exist if its package version equals to version 5.*
  describe file("/usr/local/greenplum-db-#{previous_5_version}") do
    it { should exist }
  end

  describe file("/usr/local/greenplum-db") do
    it { should be_symlink }
    its('link_path') { should eq "/usr/local/greenplum-db-#{gpdb_version}" }
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

control 'Category:server-rpm_is_upgradable' do
  describe command("rpm --install previous-6.12.0-release/greenplum-db-6.12.0-#{gpdb_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  describe command("rpm --query greenplum-db-6") do
    its('stdout') { should match /greenplum-db-6-6.12.0*/ }
    its('exit_status') { should eq 0 }
  end

  describe command("rpm --upgrade #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  describe command("rpm --query greenplum-db-6") do
    its('stdout') { should eq "greenplum-db-6-#{gpdb_version}-1.#{gpdb_rpm_arch_string}.x86_64\n"}
    its('exit_status') { should eq 0 }
  end

  describe command('rpm --erase greenplum-db-6') do
    its('exit_status') { should eq 0 }
  end
end

control 'Category:server-rpm_uninstall' do
  describe command("yum install -y #{gpdb_rpm_path}/greenplum-db-#{gpdb_rpm_arch}-x86_64.rpm") do
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


control 'Category:server-rpm_relocateable' do

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
