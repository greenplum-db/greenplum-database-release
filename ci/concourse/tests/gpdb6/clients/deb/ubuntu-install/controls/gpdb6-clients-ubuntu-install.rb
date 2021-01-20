# encoding: utf-8
# GP-RelEng

title 'Greenplum-db Clients deb integration testing'

gpdb_clients_deb_path = ENV['GPDB_CLIENTS_DEB_PATH']
gpdb_clients_version = ENV['GPDB_CLIENTS_VERSION']
gpdb_clients_deb_arch = ENV['GPDB_CLIENTS_DEB_ARCH']

control 'Category:clients-installs_on_ubuntu' do

  impact 1.0
  title 'deb installs on ubuntu'
  desc 'The deb can be installed on ubuntu with dpkg'

  # Should not already be installed
  describe command('apt-get remove -y greenplum-db-clients; dpkg-query --search greenplum-db-clients') do
    its('exit_status') { should eq 1 }
  end

  # Should be installable
  describe command("apt-get install -y \"$PWD/#{gpdb_clients_deb_path}/greenplum-db-clients-#{gpdb_clients_version}-#{gpdb_clients_deb_arch}-amd64.deb\"") do
    its('exit_status') { should eq 0 }
  end

  # Should report installed
  describe command('sleep 5; dpkg-query --show greenplum-db-clients') do
    its('stdout') { should match /greenplum-db-clients\s+0.0.0/ }
    its('exit_status') { should eq 0 }
  end

end
