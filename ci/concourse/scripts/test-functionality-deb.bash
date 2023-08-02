#!/bin/bash
set -exo pipefail

if [[ ${PLATFORM} != "ubuntu"* ]]; then
	echo "This script only supports testing Ubuntu deb packages"
	exit 1
fi

mkdir greenplum-database-release/gpdb-deb-test/gpdb_deb_installer
mv gpdb_deb_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/greenplum-db-ubuntu-amd64.deb
cp greenplum-database-release/ci/concourse/tests/gpdb6/server/install/controls/python3-compiled-file-list greenplum-database-release/gpdb-deb-test/
cp greenplum-database-release/ci/concourse/tests/gpdb6/server/install/controls/python2-compiled-file-list-ubuntu greenplum-database-release/gpdb-deb-test/
#TODO: there is no previous build release for ubuntu20.04, so we can not run upgrade test for ubuntu20.04, but will remove the condition in the future
if [[ ${PLATFORM} = "ubuntu20.04" ]]; then
	pushd greenplum-database-release/gpdb-deb-test
	godog run features/gpdb-deb.feature --tags "@UBUNTU20" || exit 1
	popd
fi

if [[ -d previous_gpdb_deb_installer ]]; then
	mv previous_gpdb_deb_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/previous-greenplum-db-ubuntu-amd64.deb
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
	mv gpdb_deb_ppa_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/greenplum-db-ubuntu-amd64.deb
	mv previous_gpdb_deb_ppa_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_deb_installer/previous-greenplum-db-ubuntu-amd64.deb
	pushd greenplum-database-release/gpdb-deb-test
	godog run features/gpdb-ppa.feature || exit 1
	popd
fi
