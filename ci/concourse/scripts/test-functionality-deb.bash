#!/bin/bash
set -exo pipefail

if [[ ${PLATFORM} != "ubuntu"* ]]; then
	echo "This script only supports testing Ubuntu deb packages"
	exit 1
fi

mkdir greenplum-database-release/gpdb-deb-test/gpdb_deb_installer
mv gpdb_deb_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/greenplum-db-ubuntu18.04-amd64.deb
if [[ -d previous_gpdb_deb_installer ]]; then
	mv previous_gpdb_deb_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/previous-greenplum-db-ubuntu18.04-amd64.deb
	pushd greenplum-database-release/gpdb-deb-test
	godog run features/gpdb-deb.feature --tags "@GPDB6" || exit 1
	popd
# gpdb7 is not released, so can not run upgrade test
else
	pushd greenplum-database-release/gpdb-deb-test
	godog run features/gpdb-deb.feature --tags "@GPDB7" || exit 1
	popd
fi

if [[ -d gpdb_deb_ppa_installer ]]; then
	mv gpdb_deb_ppa_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/greenplum-db-ubuntu18.04-amd64.deb
	mv previous_gpdb_deb_ppa_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/previous-greenplum-db-ubuntu18.04-amd64.deb
	pushd greenplum-database-release/gpdb-deb-test
	godog run features/gpdb-ppa.feature || exit 1
	popd
fi
