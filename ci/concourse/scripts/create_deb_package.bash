#!/bin/bash

set -euo pipefail
echo "Creating DEB Package..."

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# shellcheck disable=SC1090
source "$DIR"/common.bash

function download_ubuntu_gpdb_tarball() {
	mkdir "${TMP_DIR}"/bin_gpdb
	gsutil cp gs://greenplum-database-concourse-resources-intermediates-prod/greenplum-database-release/bin_gpdb_ubuntu18.04/bin_gpdb.tar.gz "${TMP_DIR}"/bin_gpdb/
}

function export_build_deb_env() {
	cd "${TMP_DIR}"
	cat <<EOF >>deb.env
export PLATFORM="ubuntu18.04"
export GPDB_NAME="greenplum-db"
export GPDB_SUMMARY="Greenplum-DB"
export GPDB_URL="https://github.com/greenplum-db/gpdb"
export GPDB_BUILDARCH="amd64"
export GPDB_DESCRIPTION="Pivotal Greenplum Server"
export GPDB_PREFIX="/usr/local"
export GPDB_OSS="true"
EOF
}

function build_gpdb_deb() {
	cat <<EOF >>build_gpdb_deb.sh
#!/bin/bash
apt-get update
apt-get install -y openssl
mkdir "${TMP_DIR}"/gpdb_deb_installer
source "${TMP_DIR}"/deb.env
bash "${TMP_DIR}"/greenplum-database-release/ci/concourse/scripts/build_gpdb_deb.bash
EOF

	chmod a+x "${TMP_DIR}"/build_gpdb_deb.sh
	docker run -w "${TMP_DIR}" -v "${TMP_DIR}":"${TMP_DIR}" -it ubuntu:18.04 "${TMP_DIR}"/build_gpdb_deb.sh
	echo "${TMP_DIR}"/gpdb_deb_installer/*.deb
}

function check() {
	cat <<EOF >>check.sh
#!/bin/bash
set -ex
apt-get update
apt-get install -y "\${1}"
EOF
	chmod a+x "${TMP_DIR}"/check.sh
	installer=$(echo "${TMP_DIR}"/gpdb_deb_installer/*.deb)
	if docker run -v "${TMP_DIR}":"${TMP_DIR}" ubuntu:18.04 "${TMP_DIR}"/check.sh "$installer"; then
		echo "passed check"
	else
		echo "not passed check"
	fi
}

function main() {
	prepare_dir
	download_code
	download_license_file
	download_ubuntu_gpdb_tarball
	export_build_deb_env
	build_gpdb_deb
	check
}

main
