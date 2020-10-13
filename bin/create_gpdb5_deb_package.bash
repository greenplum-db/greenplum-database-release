#!/usr/bin/env bash

set -eo pipefail

export BUILD_IMAGE=pivotaldata/ubuntu-gpdb-debian-dev:16.04
export BUILD_DIR="/tmp/build"

build_gpdb5_deb() {
	echo "Creating DEB Package..."
	rm -rf "${BUILD_DIR}"
	# shellcheck disable=SC2155
	export GPG_PRIVATE_KEY=$(yq read \
		"${HOME}"/workspace/gp-continuous-integration/secrets/ppa-debian-release-secrets-dev.yml gpg-private-key)
	# shellcheck disable=SC2155
	export DEBFULLNAME=$(yq read \
		"${HOME}"/workspace/gp-release/gpdb5/concourse/vars/gp5-release.dev.yml debian-package-maintainer-fullname)
	# shellcheck disable=SC2155
	export DEBEMAIL=$(yq read \
		"${HOME}"/workspace/gp-release/gpdb5/concourse/vars/gp5-release.dev.yml debian-package-maintainer-email)
	git clone --branch 5X_STABLE git@github.com:greenplum-db/gpdb.git ${BUILD_DIR}/gpdb
	docker run -it \
		-e GPG_PRIVATE_KEY \
		-e DEBFULLNAME \
		-e DEBEMAIL \
		-e RELEASE_MESSAGE="Test release" \
		-v "${PWD}":/tmp/build/greenplum-database-release \
		-v "${BUILD_DIR}"/gpdb:"${BUILD_DIR}"/gpdb \
		-v "${BUILD_DIR}"/debian_source_files:"${BUILD_DIR}"/debian_source_files \
		-w "${BUILD_DIR}" \
		"${BUILD_IMAGE}" /tmp/build/greenplum-database-release/ci/concourse/scripts/generate-ppa-debian-source-file.bash
	echo "Done. Please find the source package under /tmp/build/debian_source_files"
}

build_gpdb5_deb
