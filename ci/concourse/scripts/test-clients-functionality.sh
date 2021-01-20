#!/bin/bash

set -exo pipefail

if [[ $PLATFORM == "rhel"* ]]; then
	test_platform="centos"

	# TODO: inspec should be available on the base container
	# Install inspec v3 because v4 requires license for commercial use
	curl https://omnitruck.chef.io/install.sh | bash -s -- -P inspec -v 3

	export GPDB_CLIENTS_RPM_PATH="gpdb_clients_package_installer"
	export GPDB_CLIENTS_RPM_ARCH="$PLATFORM"
	export GPDB_CLIENTS_VERSION
	GPDB_CLIENTS_VERSION="$(rpm -qip ${GPDB_CLIENTS_RPM_PATH}/greenplum-db-clients-*-"${GPDB_CLIENTS_RPM_ARCH}"-x86_64.rpm | grep Version | awk '{print $3}' | tr --delete '\n')"

	inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-generic-rpm/ --controls=/Category:clients-.*/ --reporter documentation --no-distinct-exit --no-backend-cache
	inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-${test_platform}-install/ --controls=/Category:clients-.*/ --reporter documentation --no-backend-cache
	inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-installed/ --controls=/Category:clients-.*/ --reporter documentation --no-distinct-exit --no-backend-cache
	inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-${test_platform}-remove/ --controls=/Category:clients-.*/ --reporter documentation --no-backend-cache
elif [[ $PLATFORM == "ubuntu"* ]]; then
	test_platform="ubuntu"

	# Maybe later we can install the curl into the gpdb6-ubuntu18.04-test docker image
	apt-get update && apt-get install -y curl

	# TODO: inspec should be available on the base container
	# Install inspec v3 because v4 requires license for commercial use
	curl https://omnitruck.chef.io/install.sh | bash -s -- -P inspec -v 3

	export GPDB_CLIENTS_DEB_PATH="gpdb_clients_package_installer"
	export GPDB_CLIENTS_DEB_ARCH="$PLATFORM"
	export GPDB_CLIENTS_VERSION
	GPDB_CLIENTS_VERSION="$(dpkg --info ${GPDB_CLIENTS_DEB_PATH}/greenplum-db-clients-*-"${GPDB_CLIENTS_DEB_ARCH}"-amd64.deb | grep Version | awk '{print $2}' | tr --delete '\n')"

	inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-generic-deb/ --controls=/Category:clients-.*/ --reporter documentation --no-distinct-exit --no-backend-cache
	inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-${test_platform}-install/ --controls=/Category:clients-.*/ --reporter documentation --no-backend-cache
	inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-installed/ --controls=/Category:ubuntu-clients-.*/ --reporter documentation --no-distinct-exit --no-backend-cache
	inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-${test_platform}-remove/ --controls=/Category:clients-.*/ --reporter documentation --no-backend-cache
else
	echo "${PLATFORM} is not yet supported for Greenplum Clients 6.X"
	exit 1
fi
