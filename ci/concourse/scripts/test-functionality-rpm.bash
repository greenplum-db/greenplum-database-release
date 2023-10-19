#!/bin/bash

set -exo pipefail

# inputs:
#   - name: greenplum-database-release
#   - name: gpdb_rpm_installer
# params:
#   PLATFORM:
#	GPDB_MAJOR_VERSION:

export GPDB_RPM_PATH="gpdb_rpm_installer"
export GPDB_RPM_OSS_PATH="gpdb_rpm_oss_installer"

if [[ $PLATFORM == "rhel8"* || $PLATFORM == "rocky8"* || $PLATFORM == "oel8"* ]] && [[ $GPDB_MAJOR_VERSION == "7" ]]; then
	export GPDB_RPM_ARCH="el8"
elif [[ $PLATFORM == "rhel8"* || $PLATFORM == "rocky8"* || $PLATFORM == "oel8"* ]] && [[ $GPDB_MAJOR_VERSION == "6" ]]; then
	export GPDB_RPM_ARCH="rhel8"
elif [[ $PLATFORM == "rhel9"* || $PLATFORM == "rocky9"* || $PLATFORM == "oel9"* ]] && [[ $GPDB_MAJOR_VERSION == "6" ]]; then
	export GPDB_RPM_ARCH="rhel9"
elif [[ $PLATFORM == "rhel9"* || $PLATFORM == "rocky9"* || $PLATFORM == "oel9"* ]] && [[ $GPDB_MAJOR_VERSION == "7" ]]; then
	export GPDB_RPM_ARCH="el9"
else
	export GPDB_RPM_ARCH="$PLATFORM"
fi

# oel7 does not have previous released rpm, so it use rhel7 as previous release rpm
if [[ $PLATFORM == "oel7" ]]; then
	for dir in previous-6*; do
		old=$(ls "${dir}"/*greenplum-db-6*)
		new=$(echo "${old}" | sed 's/rhel7/oel7/1')
		mv "${old}" "${new}"
	done
	for dir in previous-5*; do
		old=$(ls "${dir}"/greenplum-db-5*)
		new=$(echo "${old}" | sed 's/rhel7/oel7/1')
		mv "${old}" "${new}"
	done
fi

if [[ $PLATFORM == "rhel6" || $PLATFORM == "rhel7" || $PLATFORM == "oel7" || $PLATFORM == "rhel8" || $PLATFORM == "rocky8" || $PLATFORM == "oel8" || $PLATFORM == "rhel9" || $PLATFORM == "rocky9" || $PLATFORM == "oel9" ]]; then
	yum install -y inspec/*.rpm
elif [[ $PLATFORM == "sles11" || $PLATFORM == "sles12" ]]; then
	rpm -Uvh inspec/*.rpm
fi

# shellcheck disable=SC2155
if [[ $GPDB_MAJOR_VERSION == "5" ]]; then
	test_prefix='greenplum-database-release/ci/concourse/tests/gpdb5/server'
	export GPDB_VERSION="$(rpm --query --info --package "${GPDB_RPM_PATH}/greenplum-db-*-${GPDB_RPM_ARCH}-x86_64.rpm" | grep Version | awk '{print $3}' | tr --delete '\n')"
	if [[ $PLATFORM == "rhel"* ]]; then
		for test_suite in generic \
			centos-install \
			installed \
			centos-remove \
			greenplum-db-5; do
			inspec exec ${test_prefix}/${test_suite}/ --reporter documentation --no-distinct-exit --no-backend-cache
		done
	elif [[ $PLATFORM == "sles"* ]]; then
		for test_suite in generic \
			sles-install \
			installed \
			sles-remove \
			greenplum-db-5; do
			inspec exec --format=documentation ${test_prefix}/${test_suite}/
		done
	fi
elif [[ $GPDB_MAJOR_VERSION == "6" ]]; then
	export RPM_GPDB_VERSION="$(rpm --query --info --package ${GPDB_RPM_PATH}/greenplum-db-6-"${GPDB_RPM_ARCH}"-x86_64.rpm | awk '/Version/{printf "%s", $3}')"
	if [[ $PLATFORM == "rhel6" || $PLATFORM == "rhel7" || $PLATFORM == "oel7" || $PLATFORM == "oel8" || $PLATFORM == "rhel8" || $PLATFORM == "rocky8" ]]; then
		test_prefix='greenplum-database-release/ci/concourse/tests/gpdb6/server'
		inspec exec ${test_prefix}/conflicts --reporter documentation --no-distinct-exit --no-backend-cache
		inspec exec ${test_prefix}/install --reporter documentation --no-distinct-exit --no-backend-cache
		inspec exec ${test_prefix}/remove --reporter documentation --no-backend-cache
		inspec exec ${test_prefix}/upgrade --reporter documentation --no-distinct-exit --no-backend-cache
	#TODO rhel9 does not have previous released artifacts, so skip confilicts and upgrade,
	# should remove the special condition later
	elif [[ $PLATFORM == "oel9" || $PLATFORM == "rhel9" || $PLATFORM == "rocky9" ]]; then
		test_prefix='greenplum-database-release/ci/concourse/tests/gpdb6/server'
		inspec exec ${test_prefix}/install --reporter documentation --no-distinct-exit --no-backend-cache
		inspec exec ${test_prefix}/remove --reporter documentation --no-backend-cache
	else
		echo "${PLATFORM} is not yet supported for Greenplum 6.X"
		exit 1
	fi
elif [[ $GPDB_MAJOR_VERSION == "7" ]]; then
	export RPM_GPDB_VERSION="$(rpm --query --info --package ${GPDB_RPM_PATH}/greenplum-db-7-"${GPDB_RPM_ARCH}"-x86_64.rpm | awk '/Version/{printf "%s", $3}')"
	if [[ $PLATFORM == "rhel7" || $PLATFORM == "rhel8" || $PLATFORM == "rocky8" || $PLATFORM == "oel8" ]]; then
		test_prefix='greenplum-database-release/ci/concourse/tests/gpdb7/server'
		inspec exec ${test_prefix}/conflicts --reporter documentation --no-distinct-exit --no-backend-cache
		inspec exec ${test_prefix}/install --reporter documentation --no-distinct-exit --no-backend-cache
		inspec exec ${test_prefix}/remove --reporter documentation --no-backend-cache
		inspec exec ${test_prefix}/upgrade --reporter documentation --no-distinct-exit --no-backend-cache
	elif [[ $PLATFORM == "oel9" || $PLATFORM == "rhel9" || $PLATFORM == "rocky9" ]]; then
		test_prefix='greenplum-database-release/ci/concourse/tests/gpdb7/server'
		inspec exec ${test_prefix}/install --reporter documentation --no-distinct-exit --no-backend-cache
		inspec exec ${test_prefix}/remove --reporter documentation --no-backend-cache
	else
		echo "${PLATFORM} is not yet supported for Greenplum 7.X"
		exit 1
	fi
else
	echo "Can't determine Greenplum Version: $GPDB_MAJOR_VERSION"
	exit 1
fi
