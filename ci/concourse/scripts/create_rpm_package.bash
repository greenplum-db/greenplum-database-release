#!/bin/bash

set -euo pipefail
centos_version=${1:-6}
echo "Creating Centos${centos_version} RPM Package..."

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck disable=SC1090
source "$DIR"/common.bash

function download_centos_gpdb_tarball() {
	mkdir "${TMP_DIR}"/bin_gpdb
	gsutil cp gs://greenplum-database-concourse-resources-intermediates-prod/greenplum-database-release/bin_gpdb_centos"${centos_version}"/bin_gpdb.tar.gz "${TMP_DIR}"/bin_gpdb/
}

function export_build_rpm_env() {
	cd "${TMP_DIR}"
	cat <<EOF >>rpm.env
export PLATFORM="rhel${centos_version}"
export GPDB_NAME="greenplum-db"
export GPDB_RELEASE="1"
export GPDB_SUMMARY="Greenplum-DB"
export GPDB_LICENSE="Pivotal Software EULA"
export GPDB_URL="https://github.com/greenplum-db/gpdb"
export GPDB_BUILDARCH="x86_64"
export GPDB_DESCRIPTION="Greenplum Database"
export GPDB_PREFIX="/usr/local"
export GPDB_OSS="true"
EOF
}

function build_gpdb_rpm() {
	cat <<EOF >>build_gpdb_rpm.sh
#!/bin/bash
mkdir "${TMP_DIR}"/gpdb_rpm_installer
yum install rpm-build -y
source "${TMP_DIR}"/rpm.env
export PYTHONPATH="${TMP_DIR}"/greenplum-database-release/ci/concourse
python "${TMP_DIR}"/greenplum-database-release/ci/concourse/scripts/build_gpdb_rpm.py
EOF
	chmod a+x "${TMP_DIR}"/build_gpdb_rpm.sh
	docker run -w "${TMP_DIR}" -v "${TMP_DIR}":"${TMP_DIR}" -it centos:"${centos_version}" "${TMP_DIR}"/build_gpdb_rpm.sh
	echo "${TMP_DIR}"/gpdb_rpm_installer/*.rpm
}

function check() {
	installer=$(echo "${TMP_DIR}"/gpdb_rpm_installer/*.rpm)
	if docker run -v "${TMP_DIR}":"${TMP_DIR}" centos:"${centos_version}" yum install -y "$installer"; then
		echo "passed check"
	else
		echo "not passed check"
	fi
}

function main() {
	prepare_dir
	download_code
	download_license_file
	download_centos_gpdb_tarball
	export_build_rpm_env
	build_gpdb_rpm
	check
}

main
