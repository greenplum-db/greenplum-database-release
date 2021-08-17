#!/bin/bash
set -exo pipefail

if [[ ${PLATFORM} != "ubuntu"* ]]; then
	echo "This script only supports testing Ubuntu deb packages"
	exit 1
fi


mkdir greenplum-database-release/gpdb-deb-test/gpdb_deb_installer
mv gpdb_deb_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/greenplum-db-6-ubuntu18.04-amd64.deb
pushd greenplum-database-release/gpdb-deb-test
godog features/gpdb-deb.feature
popd

# Set up for testing PPA package
apt install -y software-properties-common
add-apt-repository -y ppa:greenplum/db
apt-get --quiet update
apt-get --download-only install -y greenplum-db-6
mv /var/cache/apt/archives/greenplum-db-6*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/greenplum-db-6-ubuntu18.04-amd64.deb
pushd greenplum-database-release/gpdb-deb-test
godog features/gpdb-ppa.feature
popd