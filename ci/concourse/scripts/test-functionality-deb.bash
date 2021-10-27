#!/bin/bash
set -exo pipefail

if [[ ${PLATFORM} != "ubuntu"* ]]; then
	echo "This script only supports testing Ubuntu deb packages"
	exit 1
fi

mkdir greenplum-database-release/gpdb-deb-test/gpdb_deb_installer
mv gpdb_deb_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/greenplum-db-ubuntu18.04-amd64.deb
pushd greenplum-database-release/gpdb-deb-test
godog features/gpdb-deb.feature
popd

if [[ -d gpdb_deb_ppa_installer ]]; then
	mv gpdb_deb_ppa_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/greenplum-db-ubuntu18.04-amd64.deb
	pushd greenplum-database-release/gpdb-deb-test
	godog features/gpdb-ppa.feature
	popd
fi
