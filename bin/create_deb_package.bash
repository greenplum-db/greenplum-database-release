#!/usr/bin/env bash

set -eo pipefail

# shellcheck disable=SC1091
source bin/common.bash
export BUILD_IMAGE=ubuntu:18.04

build_deb_env_file() {
	cat <<EOF >>"${BUILD_ENV_FILE}"
PLATFORM=ubuntu18.04
GPDB_NAME=greenplum-db
GPDB_SUMMARY=Greenplum-DB
GPDB_URL=https://github.com/greenplum-db/gpdb
GPDB_BUILDARCH=amd64
GPDB_DESCRIPTION=Pivotal\ Greenplum\ Server
GPDB_PREFIX=/usr/local
GPDB_OSS=true
EOF
}

build_gpdb_deb() {
	cat <<EOF >>"${BUILD_SCRIPT}"
#!/bin/bash
apt-get update
apt-get install -y openssl
bash /tmp/greenplum-database-release/ci/concourse/scripts/build_gpdb_deb.bash
EOF

	chmod a+x "${BUILD_SCRIPT}"

	echo "Creating DEB Package..."
	build_gpdb
	echo "${BUILD_DIR}"/gpdb_deb_installer/*.deb
}

check_deb_installer() {
	cat <<EOF >>"${CHECK_SCRIPT}"
#!/bin/bash
set -ex
apt-get update
apt-get install -y "\${1}"
EOF

	chmod a+x "${CHECK_SCRIPT}"
	INSTALLER=$(echo "${BUILD_DIR}"/gpdb_deb_installer/*.deb) check_installer
}

main() {
	prepare
	build_deb_env_file
	build_gpdb_deb
	check_deb_installer
}

main
