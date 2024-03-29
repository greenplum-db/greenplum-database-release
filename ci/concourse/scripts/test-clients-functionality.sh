#!/bin/bash

set -exo pipefail

export GPDB_CLIENTS_PATH="gpdb_clients_package_installer"
export GPDB_CLIENTS_VERSION="0.0.0"
if [[ $PLATFORM == "rhel8"* || $PLATFORM == "rocky8"* || $PLATFORM == "oel8"* ]] && [[ $GPDB_MAJOR_VERSION == "7" ]]; then
	export GPDB_CLIENTS_ARCH="el8"
elif [[ $PLATFORM == "rhel9"* || $PLATFORM == "rocky9"* || $PLATFORM == "oel9"* ]] && [[ $GPDB_MAJOR_VERSION == "7" ]]; then
	export GPDB_CLIENTS_ARCH="el9"
elif [[ $PLATFORM == "rhel8"* || $PLATFORM == "rocky8"* || $PLATFORM == "oel8"* ]] && [[ $GPDB_MAJOR_VERSION == "6" ]]; then
	export GPDB_CLIENTS_ARCH="rhel8"
elif [[ $PLATFORM == "rhel9"* || $PLATFORM == "rocky9"* || $PLATFORM == "oel9"* ]] && [[ $GPDB_MAJOR_VERSION == "6" ]]; then
	export GPDB_CLIENTS_ARCH="rhel9"
else
	export GPDB_CLIENTS_ARCH="$PLATFORM"
fi

if [[ $PLATFORM == "rhel6" || $PLATFORM == "rhel7" || $PLATFORM == "oel7" || $PLATFORM == "rhel8" || $PLATFORM == "rocky8" || $PLATFORM == "oel8" || $PLATFORM == "rhel9" || $PLATFORM == "rocky9" || $PLATFORM == "oel9" ]]; then
	yum install -y inspec/*.rpm
elif [[ $PLATFORM == "sles11" || $PLATFORM == "sles12" ]]; then
	rpm -Uvh inspec/*.rpm
fi

if [[ $PLATFORM == "rhel"* || $PLATFORM == "sles"* || $PLATFORM == "rocky"* || $PLATFORM == "oel"* ]]; then
	GPDB_CLIENTS_VERSION="$(rpm -qip ${GPDB_CLIENTS_PATH}/greenplum-db-clients-*-"${GPDB_CLIENTS_ARCH}"-x86_64.rpm | grep Version | awk '{print $3}' | tr --delete '\n')"
	export GPDB_CLIENTS_VERSION
	if [[ "${GPDB_MAJOR_VERSION}" == 7 ]]; then
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb7/clients/rpm --reporter documentation --no-distinct-exit --no-backend-cache
	else
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb6/clients/rpm --reporter documentation --no-distinct-exit --no-backend-cache
	fi

elif [[ $PLATFORM == "ubuntu"* ]]; then
	mkdir greenplum-database-release/gpdb-deb-test/gpdb_client_deb_installer
	cp gpdb_clients_package_installer/*.deb greenplum-database-release/gpdb-deb-test/gpdb_client_deb_installer/greenplum-db-6-ubuntu-amd64.deb
	cd greenplum-database-release/gpdb-deb-test
	godog features/gpdb-client-deb.feature
else
	echo "${PLATFORM} is not yet supported for Greenplum Clients"
	exit 1
fi
