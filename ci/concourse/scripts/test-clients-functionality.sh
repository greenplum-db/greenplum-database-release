#!/bin/bash

set -exo pipefail

export GPDB_CLIENTS_PATH="gpdb_clients_package_installer"
export GPDB_CLIENTS_ARCH="$PLATFORM"
export GPDB_CLIENTS_VERSION="0.0.0"

if [[ $PLATFORM == "rhel"* ]]; then

	# TODO: inspec should be available on the base container
	# Install inspec v3 because v4 requires license for commercial use
	curl https://omnitruck.chef.io/install.sh | bash -s -- -P inspec -v 3

	GPDB_CLIENTS_VERSION="$(rpm -qip ${GPDB_CLIENTS_PATH}/greenplum-db-clients-*-"${GPDB_CLIENTS_ARCH}"-x86_64.rpm | grep Version | awk '{print $3}' | tr --delete '\n')"
	export GPDB_CLIENTS_VERSION
	inspec exec greenplum-database-release/ci/concourse/tests/gpdb6/clients/rpm --reporter documentation --no-distinct-exit --no-backend-cache

elif [[ $PLATFORM == "ubuntu"* ]]; then

	# Maybe later we can install the curl into the gpdb6-ubuntu18.04-test docker image
	apt-get update && apt-get install -y curl

	# TODO: inspec should be available on the base container
	# Install inspec v3 because v4 requires license for commercial use
	curl https://omnitruck.chef.io/install.sh | bash -s -- -P inspec -v 3
	GPDB_CLIENTS_VERSION="$(dpkg --info ${GPDB_CLIENTS_PATH}/greenplum-db-clients-*-"${GPDB_CLIENTS_ARCH}"-amd64.deb | grep Version | awk '{print $2}' | tr --delete '\n')"
	export GPDB_CLIENTS_VERSION
	inspec exec greenplum-database-release/ci/concourse/tests/gpdb6/clients/deb --reporter documentation --no-distinct-exit --no-backend-cache

else
	echo "${PLATFORM} is not yet supported for Greenplum Clients 6.X"
	exit 1
fi
