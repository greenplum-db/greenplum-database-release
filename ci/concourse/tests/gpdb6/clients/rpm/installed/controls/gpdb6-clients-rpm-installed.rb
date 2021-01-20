# encoding: utf-8
# Pa-Toolsmiths

title 'Greenplum-db RPM integration testing'

gpdb_clients_version = ENV['GPDB_CLIENTS_VERSION']

control 'Category:clients-installs_with_link' do

  impact 1.0
  title 'Package installs with symbolic link'
  desc 'When the package is installed a shorter symbolic link is created and destroyed on uninstall'

  describe file('/usr/local/greenplum-db-clients') do
    it { should be_linked_to "/usr/local/greenplum-db-clients-#{gpdb_clients_version}" }
  end

end

control 'Category:clients-greenplum_clients_path.sh' do

  impact 1.0
  title 'greenplum_clients_path.sh is correct'
  desc 'Modification must be made to the given upstream greenplum_clients_path.sh'

  # With default %{prefix}"
  describe file('/usr/local/greenplum-db-clients/greenplum_clients_path.sh') do
    its('content') { should match /GPHOME_CLIENTS=\/usr\/local\/greenplum-db-clients-#{gpdb_clients_version.split('+').first}/ }
    its('content') { should match /export GPHOME_CLIENTS/ }
  end

  describe command('source /usr/local/greenplum-db-clients/greenplum_clients_path.sh; echo $GPHOME_CLIENTS') do
    its('exit_status') { should eq 0 }
    its('stdout') { should match /\/usr\/local\/greenplum-db-clients-#{gpdb_clients_version.split('+').first}/ }
  end

end
