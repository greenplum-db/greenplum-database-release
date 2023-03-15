title 'Greenplum-db RPM integration testing'

def rpm_query(field_name, rpm_full_path)
    "rpm --query --queryformat '%{#{field_name}}' --package #{rpm_full_path}"
end

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_rpm_oss_path = ENV['GPDB_RPM_OSS_PATH']

gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']

rpm_gpdb_oss_name = 'open-source-greenplum-db-7'
rpm_oss_full_path = "#{gpdb_rpm_oss_path}/#{rpm_gpdb_oss_name}*-#{gpdb_rpm_arch}-x86_64.rpm"
rpm_gpdb_oss_version = `#{rpm_query("Version", rpm_oss_full_path)}`

rpm_gpdb_name = 'greenplum-db-7'
rpm_full_path = "#{gpdb_rpm_path}/#{rpm_gpdb_name}-#{gpdb_rpm_arch}-x86_64.rpm"
rpm_gpdb_version = `#{rpm_query("Version", rpm_full_path)}`

control 'Category:server-conflict_enterprise_to_oss_same_version' do
  version = os.release

    title "Install VTGP (Enterprise) first and GPDBVT (OSS) second for same version."

    describe command("yum install -y #{rpm_full_path}") do
      its('exit_status') {should eq 0}
      its('stdout') { should match /greenplum-db-7*/ }
    end
    describe command("yum install -y -q #{rpm_oss_full_path}") do
      its('exit_status') {should eq 1}
      if version =~ /8/
        # Error message for rhel8 is different from centos 6 and 7
        its('stderr') { should match /greenplum-db-7-.* conflicts with open-source-greenplum-db-7*/ }
        its('stderr') { should match /open-source-greenplum-db-7-.* conflicts with greenplum-db-7*/ }
      else
        its('stderr') { should match /Error: greenplum-db-7 conflicts with open-source-greenplum-db-7*/ }
        its('stderr') { should match /Error: open-source-greenplum-db-7 conflicts with greenplum-db-7*/ }
      end
    end
    describe command("yum remove -y #{rpm_gpdb_name}") do
      its('exit_status') {should eq 0}
    end


    title "Install GPDBVT (OSS) first and VTGP (Enterprise) second for same version."

    describe command("yum install -y #{rpm_oss_full_path}") do
    its('exit_status') {should eq 0}
    its('stdout') { should match /open-source-greenplum-db-7*/ }
    end

    describe command("yum install -y -q #{rpm_full_path}") do
    its('exit_status') {should eq 1}
    if version =~ /8/
      # Error message for rhel8 is different from centos 6 and 7
      its('stderr') { should match /greenplum-db-7-.* conflicts with open-source-greenplum-db-7*/ }
      its('stderr') { should match /open-source-greenplum-db-7-.* conflicts with greenplum-db-7*/ }
    else
      its('stderr') { should match /Error: greenplum-db-7 conflicts with open-source-greenplum-db-7*/ }
      its('stderr') { should match /Error: open-source-greenplum-db-7 conflicts with greenplum-db-7*/ }
    end
    end

    describe command("yum remove -y #{rpm_gpdb_oss_name}") do
    its('exit_status') {should eq 0}
    end

    title "Install VTGP (Enterprise) first and GPDBVT (OSS) second for different version."

    describe command("yum install -y previous-7.0.0-beta.0-release/greenplum-db-7.0.0-beta.0-*-x86_64.rpm") do
      its('exit_status') {should eq 0}
      its('stdout') { should match /greenplum-db-7*/ }
    end
    describe command("yum install -y -q #{rpm_oss_full_path}") do
      its('exit_status') {should eq 1}
      its('stderr') { should match /open-source-greenplum-db-7-.* conflicts with greenplum-db-7*/ }
    end
    describe command("yum remove -y #{rpm_gpdb_name}") do
      its('exit_status') {should eq 0}
    end

    title "Install GPDBVT (OSS) first and VTGP (Enterprise) second for different version."

    describe command("yum install -y previous-7.0.0-beta.0-oss-release/open-source-greenplum-db-7.0.0-beta.0-rhel8-x86_64.rpm") do
    its('exit_status') {should eq 0}
    its('stdout') { should match /open-source-greenplum-db-7*/ }
    end

    describe command("yum install -y -q #{rpm_full_path}") do
    its('exit_status') {should eq 1}
    its('stderr') { should match /greenplum-db-7-.* conflicts with open-source-greenplum-db-7*/ }
    its('stderr') { should match /open-source-greenplum-db-7-.* conflicts with greenplum-db-7*/ }
    end

    describe command("yum remove -y #{rpm_gpdb_oss_name}") do
    its('exit_status') {should eq 0}
    end
end