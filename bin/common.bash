#!/usr/bin/env bash

export BUILD_DIR="/tmp/build"
export BUILD_SCRIPT="${BUILD_DIR}"/pre_build.sh
export CHECK_SCRIPT="${BUILD_DIR}"/check.sh
export BUILD_ENV_FILE="${BUILD_DIR}"/docker-env-file

prepare() {
	if [[ ! -f ${BIN_GPDB_TARGZ} ]]; then
		echo "Please set BIN_GPDB_TARGZ env to specify the bin_gpdb.tar.gz"
		exit 1
	fi

	rm -rf "${BUILD_DIR}"
	mkdir -p "${BUILD_DIR}"/{license_file,gpdb_src,bin_gpdb,gpdb_rpm_installer,gpdb_deb_installer}
	mkdir -p "${BUILD_DIR}"/greenplum-database-release/ci/concourse/scripts

	cp -a "${BIN_GPDB_TARGZ}" "${BUILD_DIR}"/bin_gpdb/
	cp -a ci/concourse/scripts/*.spec "${BUILD_DIR}"/greenplum-database-release/ci/concourse/scripts/
	echo "content needs to discuss" >"${BUILD_DIR}"/license_file/open_source_license_greenplum-database-6.0.0-97773a0-dev.txt
	echo "content needs to discuss" >"${BUILD_DIR}"/gpdb_src/LICENSE
	echo "content needs to discuss" >"${BUILD_DIR}"/gpdb_src/COPYRIGHT
}

check_centos_version() {
	if [[ "${CENTOS_VERSION}" != "6" && "${CENTOS_VERSION}" != "7" ]]; then
		echo "Please set CENTOS_VERSION env to specify centos version, validated values: [6, 7]"
		exit 1
	fi
}

build_gpdb() {
	docker run --env-file "${BUILD_ENV_FILE}" \
		-w "${BUILD_DIR}" \
		-v "$PWD":/tmp/greenplum-database-release \
		-v "${BUILD_DIR}":"${BUILD_DIR}" \
		-it "${BUILD_IMAGE}" \
		"${BUILD_DIR}"/pre_build.sh
}

check_installer() {
	if docker run -v "${BUILD_DIR}":"${BUILD_DIR}" -it "${BUILD_IMAGE}" "${CHECK_SCRIPT}" "$INSTALLER"; then
		echo "Passed check! Install ${INSTALLER} package successfully."
	else
		echo "Not passed check! Install ${INSTALLER} package failed."
	fi
}
