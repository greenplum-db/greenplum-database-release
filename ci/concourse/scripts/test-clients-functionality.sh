#!/bin/bash

set -exo pipefail

export GPDB_CLIENTS_PATH="gpdb_clients_package_installer"
export GPDB_CLIENTS_ARCH="$PLATFORM"
export GPDB_CLIENTS_VERSION="0.0.0"

if [[ $PLATFORM == "rhel"* || $PLATFORM == "sles"* || $PLATFORM == "rocky"* ]]; then

	# TODO: inspec should be available on the base container
	# Install inspec v3 because v4 requires license for commercial use
	curl https://omnitruck.chef.io/install.sh | bash -s -- -P inspec -v 3

	GPDB_CLIENTS_VERSION="$(rpm -qip ${GPDB_CLIENTS_PATH}/greenplum-db-clients-*-"${GPDB_CLIENTS_ARCH}"-x86_64.rpm | grep Version | awk '{print $3}' | tr --delete '\n')"
	export GPDB_CLIENTS_VERSION
	if [[ "${GPDB_MAJOR_VERSION}" == 7 ]]; then
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb7/clients/rpm --reporter documentation --no-distinct-exit --no-backend-cache
	else
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb6/clients/rpm --reporter documentation --no-distinct-exit --no-backend-cache
	fi

elif [[ $PLATFORM == "ubuntu"* ]]; then
	mkdir greenplum-database-release/gpdb-deb-test/gpdb_client_deb_installer
	cp gpdb_clients_package_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_client_deb_installer/greenplum-db-6-ubuntu18.04-amd64.deb
	cd greenplum-database-release/gpdb-deb-test
	godog features/gpdb-client-deb.feature
else
	echo "${PLATFORM} is not yet supported for Greenplum Clients 6.X"
	exit 1
fi
