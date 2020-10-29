#!/bin/bash

set -exo pipefail

# inputs:
#   - name: gp-release
#   - name: gpdb_rpm_installer
# params:
#   PLATFORM:

export GPDB_RPM_PATH="gpdb_rpm_installer"
export GPDB_RPM_ARCH=$PLATFORM
GPDB_VERSION="$(rpm --query --info --package "${GPDB_RPM_PATH}/greenplum-db-*-${GPDB_RPM_ARCH}-x86_64.rpm" | grep Version | awk '{print $3}' | tr --delete '\n')"
export GPDB_VERSION

if [[ $PLATFORM == "rhel"* ]]; then
	# TODO: inspec should be available on the base container
	# Install inspec v3 because v4 requires license for commercial use
	curl https://omnitruck.chef.io/install.sh | bash -s -- -P inspec -v 3

	for test_suite in gpdb_generic_rpm \
		gpdb_centos_install \
		gpdb_installed \
		gpdb_centos_remove \
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
	for test_suite in gpdb_generic_rpm \
		gpdb_sles_install \
		gpdb_installed \
		gpdb_sles_remove \
		greenplum-db-5-rpm; do
		inspec exec --format=documentation greenplum-database-release/ci/concourse/tests/${test_suite}/
	done
fi
