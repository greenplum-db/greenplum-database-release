# encoding: utf-8
# GP-Releng

title 'Greenplum-db Clients deb package integration testing'

gpdb_clients_deb_path = ENV['GPDB_CLIENTS_PATH']
gpdb_clients_deb_arch = ENV['GPDB_CLIENTS_ARCH']
gpdb_clients_version = ENV['GPDB_CLIENTS_VERSION']

control 'Category:clients-deb_metadata' do

  title 'deb metadata is valid'
  desc 'The deb metadata is valid per product requirements'

  describe command("dpkg --info #{gpdb_clients_deb_path}/greenplum-db-clients-*-#{gpdb_clients_deb_arch}-amd64.deb | grep Package") do
    its('stdout') { should match /Package: greenplum-db-clients/ }
  end

  describe command("dpkg --info #{gpdb_clients_deb_path}/greenplum-db-clients-*-#{gpdb_clients_deb_arch}-amd64.deb | grep Homepage") do
    its('stdout') { should match /Homepage: https:\/\/network.pivotal.io\/products\/pivotal-gpdb\// }
  end

  # Test specified URL is reachable
  describe command("curl -s --head $(dpkg --info #{gpdb_clients_deb_path}/greenplum-db-clients-*-#{gpdb_clients_deb_arch}-amd64.deb | grep Homepage | awk '{print $2}') | head -n 1 | grep 'HTTP/1.[01] [23]..'") do
    its('stdout') { should match /HTTP\/1.1 200 OK/ }
  end

end

control 'Category:clients-deb_installable' do

    impact 1.0
    title 'GPDB Clients DEB Functionality Testing'
    desc 'Test functionality of greenplum-db-clients'

    # Should not already be installed
    describe command('dpkg -l greenplum-db-clients 2>&1') do
      its('stdout') { should match /dpkg-query: no packages found matching greenplum-db-clients/ }
    end
  
    # Should be installable
    describe command("apt-get install -y $PWD/#{gpdb_clients_deb_path}/greenplum-db-clients-*-#{gpdb_clients_deb_arch}-amd64.deb") do
      its('exit_status') { should eq 0 }
    end
  
    # Should create the proper symbolic link
    describe file("/usr/local/greenplum-db-clients") do
      it { should be_linked_to "/usr/local/greenplum-db-clients-#{gpdb_clients_version}" }
    end

    describe file("/usr/local/greenplum-db-clients/greenplum_clients_path.sh") do
      its('content') { should match /GPHOME_CLIENTS=\/usr\/local\/greenplum-db-clients-#{gpdb_clients_version.split('+').first}/ }
      its('content') { should match /export GPHOME_CLIENTS/ }
    end

    # Should report installed
    describe command('sleep 1; dpkg --status greenplum-db-clients | grep Status') do
      its('stdout') { should match /Status: install ok installed/ }
    end
  
    # Should be uninstallable
    describe command('dpkg -P greenplum-db-clients') do
      its('exit_status') { should eq 0 }
    end
  
    # Should report uninstalled
    describe command('dpkg -l greenplum-db-clients 2>&1') do
      its('stdout') { should match /dpkg-query: no packages found matching greenplum-db-clients/ }
    end

    # Should remove link created in %post scriptlet
    describe file("/usr/local/greenplum-db-clients") do
      it { should_not exist }
    end
  end