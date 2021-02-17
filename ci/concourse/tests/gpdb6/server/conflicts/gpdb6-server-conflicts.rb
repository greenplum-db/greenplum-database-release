title 'Greenplum-db RPM integration testing'

def rpm_query(field_name, rpm_full_path)
    "rpm --query --queryformat '%{#{field_name}}' --package #{rpm_full_path}"
end

gpdb_rpm_path = ENV['GPDB_RPM_PATH']
gpdb_rpm_oss_path = ENV['GPDB_RPM_OSS_PATH']

gpdb_rpm_arch = ENV['GPDB_RPM_ARCH']


previous_version = File.read('previous-6-release/version').split('#').first if File.exist?('previous-6-release/version')
previous_oss_version = File.read('previous-6-oss-release/version').split('#').first if File.exist?('previous-6-oss-release/version')


rpm_gpdb_oss_name = 'open-source-greenplum-db-6'
rpm_oss_full_path = "#{gpdb_rpm_oss_path}/#{rpm_gpdb_oss_name}-#{gpdb_rpm_arch}-x86_64.rpm"
rpm_gpdb_oss_version = `#{rpm_query("Version", rpm_oss_full_path)}`

rpm_gpdb_name = 'greenplum-db-6'
rpm_full_path = "#{gpdb_rpm_path}/#{rpm_gpdb_name}-#{gpdb_rpm_arch}-x86_64.rpm"
rpm_gpdb_version = `#{rpm_query("Version", rpm_full_path)}`

control 'Category:server-conflict_enterprise_to_oss_same_version' do
  # Previous 6 release not yet available for Photon
  if os.redhat?
    describe command("yum install -y #{rpm_full_path}") do
      its('exit_status') {should eq 0}
    end
    describe command("yum install -y #{rpm_oss_full_path}") do
      its('exit_status') {should eq 1}
    end
  end
end