title 'Greenplum-db RPM integration testing'

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']

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

control 'RPM installation' do

  title 'RPM is installable with yum command'
  desc 'The RPM can be installed and then uninstalled with the yum command'

  describe command("rpm --install #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

  describe file("/usr/local/greenplum-db") do
    it { should be_symlink }
    its('link_path') { should eq "/usr/local/greenplum-db-#{gpdb_version}" }
  end

  describe command("rpm --erase #{rpm_gpdb_name}") do
    its('exit_status') { should eq 0 }
  end

  describe file("/usr/local/greenplum-db-#{gpdb_version}/greenplum_path.sh.rpmsave") do
    it { should_not exist }
  end

  describe file("/usr/local/greenplum-db") do
    it { should_not exist }
  end

end


control 'RPM config files' do

  title 'greenplum_path.sh is preserved if its content changed'

  describe command("rpm --install #{rpm_full_path}") do
    its('exit_status') { should eq 0 }
  end

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

control 'RPM obsoletes GPDB 6' do

  title 'when both greenplum-db version 6.2.1 and greenplum-db-6 are installed.'

  describe command("yum install -y previous-6-release/greenplum-db-#{previous_6_version}-#{gpdb_rpm_arch}-x86_64.rpm") do
    before do
      # photon3 doesn't have previous release of gpdb6
      skip if gpdb_rpm_arch == "photon3"
    end
    its('exit_status') { should eq 0 }
  end

  describe command("yum install -y #{rpm_full_path}") do
    before do
      # photon3 doesn't have previous release of gpdb6
      skip if gpdb_rpm_arch == "photon3"
    end
    its('exit_status') { should eq 0 }
  end

  # the previous gpdb version 6 package will be removed
  describe command("yum list installed greenplum-db") do
    before do
      # photon3 doesn't have previous release of gpdb6
      skip if gpdb_rpm_arch == "photon3"
    end
    its('exit_status') { should eq 1 }
  end

  # the directory belongs to package: greenplum-db will be removed if its package version equals to version 6.*
  describe file("/usr/local/greenplum-db-#{previous_6_version}") do
    before do
      # photon3 doesn't have previous release of gpdb6
      skip if gpdb_rpm_arch == "photon3"
    end
    it { should_not exist }
  end

  # the link belongs to package: greenplum-db will be removed if its package version equals to version 6.*
  # so the link belongs to previous gpdb version 6 pacakge will still exist
  describe file("/usr/local/greenplum-db") do
    before do
      # photon3 doesn't have previous release of gpdb6
      skip if gpdb_rpm_arch == "photon3"
    end
    it { should be_symlink }
    its('link_path') { should eq "/usr/local/greenplum-db-#{gpdb_version}" }
  end

  describe file("/usr/local/greenplum-db-#{gpdb_version}") do
    before do
      # photon3 doesn't have previous release of gpdb6
      skip if gpdb_rpm_arch == "photon3"
    end
    it { should be_directory }
  end

  describe command("yum remove -y #{rpm_gpdb_name}") do
    before do
      # photon3 doesn't have previous release of gpdb6
      skip if gpdb_rpm_arch == "photon3"
    end
    its('exit_status') { should eq 0 }
  end

end

control 'RPM with GPDB 5' do

  title 'when both greenplum-db version 5.2.1 and greenplum-db-6 are installed.'

  describe command("yum install -y previous-5-release/greenplum-db-#{previous_5_version}-#{gpdb_rpm_arch}-x86_64.rpm") do
    before do
      # photon3 doesn't have previous release of gpdb5
      skip if gpdb_rpm_arch == "photon3"
    end
    its('exit_status') { should eq 0 }
  end

  describe command("yum install -y #{rpm_full_path}") do
    before do
      # photon3 doesn't have previous release of gpdb5
      skip if gpdb_rpm_arch == "photon3"
    end
    its('exit_status') { should eq 0 }
  end

  # the previous gpdb version 5 package will still exist
  describe command("yum list installed greenplum-db") do
    before do
      # photon3 doesn't have previous release of gpdb5
      skip if gpdb_rpm_arch == "photon3"
    end
    its('exit_status') { should eq 0 }
  end

  # the directory belongs to package: greenplum-db will still exist if its package version equals to version 5.*
  describe file("/usr/local/greenplum-db-#{previous_5_version}") do
    before do
      # photon3 doesn't have previous release of gpdb5
      skip if gpdb_rpm_arch == "photon3"
    end
    it { should exist }
  end

  describe file("/usr/local/greenplum-db") do
    before do
      # photon3 doesn't have previous release of gpdb5
      skip if gpdb_rpm_arch == "photon3"
    end
    it { should be_symlink }
    its('link_path') { should eq "/usr/local/greenplum-db-#{gpdb_version}" }
  end

  describe file("/usr/local/greenplum-db-#{gpdb_version}") do
    before do
      # photon3 doesn't have previous release of gpdb5
      skip if gpdb_rpm_arch == "photon3"
    end
    it { should be_directory }
  end

  describe command("yum remove -y #{rpm_gpdb_name}") do
    before do
      # photon3 doesn't have previous release of gpdb5
      skip if gpdb_rpm_arch == "photon3"
    end
    its('exit_status') { should eq 0 }
  end

  describe command("yum remove -y greenplum-db") do
    before do
      # photon3 doesn't have previous release of gpdb5
      skip if gpdb_rpm_arch == "photon3"
    end
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
