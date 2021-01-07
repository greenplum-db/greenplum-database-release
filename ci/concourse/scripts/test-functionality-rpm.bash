#!/bin/bash

set -exo pipefail

# inputs:
#   - name: greenplum-database-release
#   - name: gpdb_rpm_installer
# params:
#   PLATFORM:
#	GPDB_MAJOR_VERSION:

export GPDB_RPM_PATH="gpdb_rpm_installer"
export GPDB_RPM_ARCH=$PLATFORM
# shellcheck disable=SC2155
if [[ $GPDB_MAJOR_VERSION == "5" ]]; then
	export GPDB_VERSION="$(rpm --query --info --package "${GPDB_RPM_PATH}/greenplum-db-*-${GPDB_RPM_ARCH}-x86_64.rpm" | grep Version | awk '{print $3}' | tr --delete '\n')"
	if [[ $PLATFORM == "rhel"* ]]; then
		# TODO: inspec should be available on the base container
		# Install inspec v3 because v4 requires license for commercial use
		curl https://omnitruck.chef.io/install.sh | bash -s -- -P inspec -v 3

		for test_suite in gpdb5-generic-rpm \
			gpdb5-centos-install \
			gpdb5-installed \
			gpdb5-centos-remove \
			greenplum-db-5-rpm; do
			inspec exec greenplum-database-release/ci/concourse/tests/${test_suite}/ --reporter documentation --no-distinct-exit --no-backend-cache
		done
	elif [[ $PLATFORM == "sles"* ]]; then
		# Install inspec
		wget --no-check-certificate https://packages.chef.io/files/stable/inspec/1.31.1/sles/11/inspec-1.31.1-1.sles11.x86_64.rpm
		zypper --non-interactive install inspec-1.31.1-1.sles11.x86_64.rpm

		# backend-cache wasn't added until inspec 1.47.0
		#   - https://discourse.chef.io/t/inspec-v1-47-0-released/12066
		# hence no need to disable it
		for test_suite in gpdb5-generic-rpm \
			gpdb5-sles-install \
			gpdb5-installed \
			gpdb5-sles-remove \
			greenplum-db-5-rpm; do
			inspec exec --format=documentation greenplum-database-release/ci/concourse/tests/${test_suite}/
		done
	fi
elif [[ $GPDB_MAJOR_VERSION == "6" ]]; then
	export RPM_GPDB_VERSION="$(rpm --query --info --package ${GPDB_RPM_PATH}/greenplum-db-"${GPDB_RPM_ARCH}"-x86_64.rpm | awk '/Version/{printf "%s", $3}')"
	if [[ $PLATFORM == "rhel"* ]]; then
		curl https://omnitruck.chef.io/install.sh | bash -s -- -P inspec -v 3
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-generic-rpm/ --controls=/Category:server-.*/ --reporter documentation --no-distinct-exit --no-backend-cache
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-centos-install/ --controls=/Category:server-.*/ --reporter documentation --no-backend-cache
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-installed/ --controls=/Category:server-.*/ --reporter documentation --no-distinct-exit --no-backend-cache
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-centos-remove/ --controls=/Category:server-.*/ --reporter documentation --no-backend-cache
		inspec exec greenplum-database-release/ci/concourse/tests/greenplum-db-6-rpm/ --reporter documentation --no-distinct-exit --no-backend-cache
	elif [[ $PLATFORM == "photon"* ]]; then
		wget https://packages.chef.io/files/stable/inspec/3.9.3/el/7/inspec-3.9.3-1.el7.x86_64.rpm
		rpm --install inspec-3.9.3-1.el7.x86_64.rpm
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-generic-rpm/ --controls=/Category:server-.*/ --reporter documentation --no-distinct-exit --no-backend-cache
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-photon-install/ --controls=/Category:server-.*/ --reporter documentation --no-backend-cache
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-installed/ --controls=/Category:server-.*/ --reporter documentation --no-distinct-exit --no-backend-cache
		inspec exec greenplum-database-release/ci/concourse/tests/gpdb6-photon-remove/ --controls=/Category:server-.*/ --reporter documentation --no-backend-cache
		inspec exec greenplum-database-release/ci/concourse/tests/greenplum-db-6-rpm/ --reporter documentation --no-distinct-exit --no-backend-cache
	else
		echo "${PLATFORM} is not yet supported for Greenplum 6.X"
		exit 1
	fi
else
	echo "Can't determine Greenplum Version: $GPDB_MAJOR_VERSION"
	exit 1
fi
