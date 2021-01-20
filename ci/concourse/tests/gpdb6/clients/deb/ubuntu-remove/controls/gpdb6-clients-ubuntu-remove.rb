# encoding: utf-8
# GP-RelEng

title 'Greenplum-db Clients deb integration testing'

gpdb_clients_deb_path = ENV['GPDB_CLIENTS_DEB_PATH']
gpdb_clients_version = ENV['GPDB_CLIENTS_VERSION']
gpdb_clients_deb_arch = ENV['GPDB_CLIENTS_DEB_ARCH']

control 'Category:clients-uninstalls_on_ubuntu' do

  impact 1.0
  title 'deb uninstalls on ubuntu'
  desc 'The deb uninstalls on ubuntu with apt'

  prefix="/usr/local"

  # Should report installed
  describe command('dpkg-query --show greenplum-db-clients') do
    its('stdout') { should match /greenplum-db-clients\s+0.0.0/ }
    its('exit_status') { should eq 0 }
  end

  # Should be uninstallable
  describe command('apt-get remove -y greenplum-db-clients') do
    its('exit_status') { should eq 0 }
  end

  # Should report uninstalled
  describe command('dpkg-query --search greenplum-db-clients') do
    its('exit_status') { should eq 1 }
  end

  # Should remove link created in %post scriptlet
  describe file("#{prefix}/greenplum-db-clients") do
    it { should_not exist }
  end

end
