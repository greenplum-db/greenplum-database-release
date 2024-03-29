#!/usr/bin/env bash

set -eu

main() {
	local platform
	local docker_image_tag
	case "${CENTOS_VERSION}" in
	[6-7])
		platform="rhel${CENTOS_VERSION}"
		docker_image_tag="${CENTOS_VERSION}-gcc6.2-llvm3.7"
		;;
	*)
		printf "Unexpected value for \$CENTOS_VERSION='%s'\n" "${CENTOS_VERSION}"
		exit 1
		;;
	esac

	local bin_gpdb_path
	bin_gpdb_path="${BIN_GPDB_TARGZ}"

	test -f "${bin_gpdb_path}" || {
		printf "File in \$BIN_GPDB_TARGZ does not exist\n"
		exit 1
	}

	local gpdb_major_version
	gpdb_major_version="$(echo "${GPDB_VERSION}" | cut -d '.' -f1)"

	docker run -it \
		-v "${PWD}":/tmp/greenplum-database-release \
		-v "${bin_gpdb_path}":/tmp/bin_gpdb/bin_gpdb.tar.gz \
		-v "${PWD}":/tmp/gpdb_rpm_installer \
		-w /tmp \
		-e GPDB_VERSION="${GPDB_VERSION}" \
		-e PLATFORM="${platform}" \
		-e GPDB_BUILDARCH="x86_64" \
		-e GPDB_DESCRIPTION="Greenplum Database" \
		-e GPDB_GROUP="Applications/Databases" \
		-e GPDB_LICENSE="VMware Software EULA" \
		-e GPDB_NAME="greenplum-db-${gpdb_major_version}" \
		-e GPDB_PREFIX="/usr/local" \
		-e GPDB_RELEASE=1 \
		-e GPDB_SUMMARY="Greenplum-DB" \
		-e GPDB_URL="https://network.tanzu.vmware.com/products/vmware-greenplum/" \
		pivotaldata/centos-gpdb-dev:"${docker_image_tag}" \
		/tmp/greenplum-database-release/ci/concourse/scripts/build_gpdb5_rpm.sh
}

main
