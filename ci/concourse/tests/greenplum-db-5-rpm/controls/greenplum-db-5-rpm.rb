title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']

def rpm_query(field_name, rpm_full_path)
  "rpm --query --queryformat '%{#{field_name}}' --package #{rpm_full_path}"
end

rpm_full_path = "#{gpdb_rpm_path}/greenplum-db-5.99.0-#{gpdb_rpm_arch}-x86_64.rpm"
rpm_gpdb_version = `#{rpm_query("Version", rpm_full_path)}`
rpm_gpdb_name = 'greenplum-db-5'

# for RPMs `-` is an invalid character for the version string
# when the RPM was built, any `-` was converted to `_`
gpdb_version = rpm_gpdb_version.sub("_", "-") if rpm_gpdb_version != nil
previous_6_version = File.read('previous-6-release/version').split('#').first if File.exist?('previous-6-release/version')
previous_5_version = File.read('previous-5-release/version').split('#').first if File.exist?('previous-5-release/version')

pkg_mgr = gpdb_rpm_arch.start_with?("rhel") ? "yum" : "zypper"

control 'RPM metadata' do

  title 'RPM metadata is valid'
  desc 'The RPM metadata is valid per product requirements'

  def rpm_query(field_name, rpm_full_path)
    "rpm --query --queryformat '%{#{field_name}}' --package #{rpm_full_path}"
  end

  describe command(rpm_query("Group", rpm_full_path)) do
    # In GPDB5, we still define Group to new greenplum-db-5 package
    # to be compatible with the old previous 5 greenplum-db pacakge
    its('stdout') { should cmp "Applications/Databases" }
  end

  describe command(rpm_query("Name", rpm_full_path)) do
    its('stdout') { should cmp rpm_gpdb_name }
  end

  describe command(rpm_query("URL", rpm_full_path)) do
    its('stdout') { should cmp "https://network.pivotal.io/products/pivotal-gpdb/" }
  end

end

control 'RPM installation' do

  title 'RPM is installable with #{pkg_mgr} command'
  desc 'The RPM can be installed and then uninstalled with the #{pkg_mgr} command'

  describe command("#{pkg_mgr} install -y #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  describe file("/usr/local/greenplum-db") do
    it { should be_symlink }
    its('link_path') { should eq "/usr/local/greenplum-db-#{gpdb_version}" }
  end

  describe command("#{pkg_mgr} remove -y #{rpm_gpdb_name}") do
    its('exit_status') { should eq 0 }
  end

  describe file("/usr/local/greenplum-db-#{gpdb_version}/greenplum_path.sh.rpmsave") do
    it { should exist }
  end

  describe file("/usr/local/greenplum-db") do
    it { should_not exist }
  end

end


control 'RPM config files' do

  title 'greenplum_path.sh is preserved if its content changed'

  describe command("#{pkg_mgr} install -y #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  # make a change to the config file: greenplum-db-5/greenplum_path.sh
  describe command("echo \"# make a change\" >> /usr/local/greenplum-db-#{gpdb_version}/greenplum_path.sh") do
    its('exit_status') { should eq 0 }
  end

  describe command("#{pkg_mgr} remove -y #{rpm_gpdb_name}") do
    its('exit_status') { should eq 0 }
  end

  # When performing uninstall(it can also be downgrade or upgrade) of the RPM package,
  # any changes to the installed greenplum-db-6/greenplum_path.sh file shall not be removed.
  describe file("/usr/local/greenplum-db-#{gpdb_version}/greenplum_path.sh.rpmsave") do
    it { should exist }
  end

  # delete the directory /usr/local/greenplum-db-5.*.*
  describe command("rm -rf /usr/local/greenplum-db-#{gpdb_version}") do
    its('exit_status') { should eq 0 }
  end

end

control 'RPM obsoletes GPDB 5' do

  title 'when both greenplum-db version 5.25.0 and greenplum-db-5 are installed.'

  def installed?(package_name)
    if ENV['GPDB_RPM_ARCH'].start_with?("rhel")
      "yum list installed #{package_name}"
    else
      "zypper search --match-exact --installed-only #{package_name}"
    end
  end

  describe command("#{pkg_mgr} install -y previous-5-release/greenplum-db-#{previous_5_version}-#{gpdb_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  describe command("#{pkg_mgr} install -y #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  # the previous gpdb version 5 package will be removed
  describe command(installed?("greenplum-db")) do
    its('exit_status') { should_not eq 0 }
  end

  # the directory belongs to package: greenplum-db will be removed if its package version equals to version 6.*
  describe file("/usr/local/greenplum-db-#{previous_5_version}") do
    it { should_not exist }
  end

  # older GPDB 5 RPMs have a bug in the %postun that always removes "/usr/local/greenplum-db"
  # this will be fixed with the new greenplum-db-5 RPM package
  # these controls capture the expected bug behavior
  describe file("/usr/local/greenplum-db") do
    it { should_not exist }
  end if previous_5_version == "5.25.0"

  # once greenplum-db-5 RPMs are available on TanzuNet, upgrading RPMs should leave a symlink from
  # /usr/local/greenplum-db to the new packages install location
  describe file("/usr/local/greenplum-db") do
    it { should be_symlink }
    its('link_path') { should eq "/usr/local/greenplum-db-#{gpdb_version}" }
  end if previous_5_version != "5.25.0"

  describe file("/usr/local/greenplum-db-#{gpdb_version}") do
    it { should be_directory }
  end

  describe command("#{pkg_mgr} remove -y #{rpm_gpdb_name}") do
    its('exit_status') { should eq 0 }
  end

end

control 'RPM with GPDB 6' do

  title 'when both greenplum-db version 6.2.1 and greenplum-db-5 are installed.'

  only_if do
    gpdb_rpm_arch.start_with?("rhel")
  end

  describe command("yum install -y previous-6-release/greenplum-db-#{previous_6_version}-#{gpdb_rpm_arch}-x86_64.rpm") do
    its('exit_status') { should eq 0 }
  end

  describe command("yum install -y #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  # the previous gpdb version 6 package will still exist
  describe command("yum list installed greenplum-db") do
    its('exit_status') { should eq 0 }
  end

  # the directory belongs to package: greenplum-db will still exist if its package version equals to version 6.2.1
  describe file("/usr/local/greenplum-db-#{previous_6_version}") do
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

control 'RPM is upgradable' do
# TODO, need greenplum-db-5 to be published to pivnet, at that time, write a upgradeable test
# from greenplum-db-5 with lower version to greenplum-db-5 with upper version is possible.
end

control 'RPM is relocateable' do

  title 'RPM is relocateable'
  desc 'The RPM should allow specifying an installation PREFIX and handle accordingly'

  prefix="/opt"

  describe command("rpm --prefix=#{prefix} --install #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

 # The package should create an $prefix/greenplum-db symbolic link
  describe file("#{prefix}/greenplum-db") do
    it { should be_symlink }
    its('link_path') { should eq "#{prefix}/greenplum-db-#{gpdb_version}" }
  end

  describe file("#{prefix}/greenplum-db-#{gpdb_version}/greenplum_path.sh") do
    its('content') { should match /GPHOME=#{prefix}\/greenplum-db-#{gpdb_version}.*/ }
    its('content') { should match /export GPHOME/ }
  end

  describe command("rpm --erase #{rpm_gpdb_name}") do
    its('exit_status') { should eq 0 }
  end

  describe file("#{prefix}/greenplum-db") do
    it { should_not exist }
  end

end
