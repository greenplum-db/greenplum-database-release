#!/usr/bin/env bash

set -eo pipefail

# shellcheck disable=SC1091
source bin/common.bash
export BUILD_IMAGE=centos:${CENTOS_VERSION}

build_rpm_env_file() {
	cat <<EOF >>"${BUILD_ENV_FILE}"
PLATFORM=rhel${CENTOS_VERSION}
GPDB_NAME=greenplum-db
GPDB_RELEASE=1
GPDB_SUMMARY=Greenplum-DB
GPDB_LICENSE=Pivotal\ Software\ EULA
GPDB_URL=https://github.com/greenplum-db/gpdb
GPDB_BUILDARCH=x86_64
GPDB_DESCRIPTION=Greenplum Database
GPDB_PREFIX=/usr/local
GPDB_OSS=true
EOF
}

build_gpdb_rpm() {
	cat <<EOF >>"${BUILD_SCRIPT}"
#!/bin/bash
yum install -y rpm-build
export PYTHONPATH=/tmp/greenplum-database-release/ci/concourse
python /tmp/greenplum-database-release/ci/concourse/scripts/build_gpdb_rpm.py
EOF
	chmod a+x "${BUILD_SCRIPT}"
	echo "Creating Centos${CENTOS_VERSION} RPM Package..."
	build_gpdb
	echo "${BUILD_DIR}"/gpdb_rpm_installer/*.rpm
}

check_rpm_installer() {
	cat <<EOF >>"${CHECK_SCRIPT}"
#!/bin/bash
set -ex
yum install -y  "\${1}"
EOF

	chmod a+x "${CHECK_SCRIPT}"
	INSTALLER=$(echo "${BUILD_DIR}"/gpdb_rpm_installer/*.rpm) check_installer
}

main() {
	check_centos_version
	prepare
	build_rpm_env_file
	build_gpdb_rpm
	check_rpm_installer
}

main
