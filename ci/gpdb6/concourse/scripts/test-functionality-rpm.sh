#!/bin/bash

set -exo pipefail

# inputs:
#   - name: greenplum-database-release
#   - name: gpdb_rpm_installer
# params:
#   PLATFORM:

export GPDB_RPM_PATH="gpdb_rpm_installer"
export GPDB_RPM_ARCH=$PLATFORM
# shellcheck disable=SC2155
export RPM_GPDB_VERSION="$(rpm --query --info --package ${GPDB_RPM_PATH}/greenplum-db-"${GPDB_RPM_ARCH}"-x86_64.rpm | awk '/Version/{printf "%s", $3}')"

concourse_root="gpdb6/concourse"

if [[ $PLATFORM == "rhel"* ]]; then
	test_platform="centos"

	inspec exec greenplum-database-release/ci/${concourse_root}/tests/gpdb-generic-rpm/ --controls=/Category:server-.*/ --reporter documentation --no-distinct-exit --no-backend-cache
	inspec exec greenplum-database-release/ci/${concourse_root}/tests/gpdb-${test_platform}-install/ --controls=/Category:server-.*/ --reporter documentation --no-backend-cache
	inspec exec greenplum-database-release/ci/${concourse_root}/tests/gpdb-installed/ --controls=/Category:server-.*/ --reporter documentation --no-distinct-exit --no-backend-cache
	inspec exec greenplum-database-release/ci/${concourse_root}/tests/gpdb-${test_platform}-remove/ --controls=/Category:server-.*/ --reporter documentation --no-backend-cache
	inspec exec greenplum-database-release/ci/${concourse_root}/tests/greenplum-db-6-rpm/ --reporter documentation --no-distinct-exit --no-backend-cache
else
	echo "${PLATFORM} is not yet supported for Greenplum 6.X"
	exit 1
fi
