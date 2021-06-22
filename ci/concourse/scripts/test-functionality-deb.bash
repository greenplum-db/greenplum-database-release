#!/bin/bash
set -exo pipefail

if [[ ${PLATFORM} != "ubuntu"* ]]; then
	echo "This script only supports testing Ubuntu deb packages"
	exit 1
fi

mkdir greenplum-database-release/gpdb-deb-test/gpdb_deb_installer
mv gpdb_deb_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/greenplum-db-6-ubuntu18.04-amd64.deb
cd greenplum-database-release/gpdb-deb-test
godog features/gpdb-deb.feature
