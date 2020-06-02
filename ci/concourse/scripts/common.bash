#!/usr/bin/env bash

export TMP_DIR="/tmp/create-package"

function prepare_dir() {
	if [ -d "${TMP_DIR}" ]; then rm -rf "${TMP_DIR}"; fi
	mkdir "${TMP_DIR}"
}

function download_code() {
	git clone --depth 1 git@github.com:greenplum-db/greenplum-database-release.git "${TMP_DIR}"/greenplum-database-release
	cd "${TMP_DIR}"/greenplum-database-release || return
	git checkout master
	git pull --ff-only
	git clone --depth 1 --branch 6X_STABLE https://github.com/greenplum-db/gpdb.git "${TMP_DIR}"/gpdb_src
	cd "${TMP_DIR}"/gpdb_src || return
	git checkout 6X_STABLE
	git pull --ff-only
	git clone --depth 1 --branch master git@github.com:pivotal/gp-continuous-integration.git "${TMP_DIR}"/gp-continuous-integration
	cd "${TMP_DIR}"/gp-continuous-integration || return
	git checkout master
	git pull --ff-only
}

function download_license_file() {
	cd "${TMP_DIR}" || return
	/usr/local/bin/bosh interpolate \
		greenplum-database-release/ci/concourse/pipelines/gpdb_opensource_release.yml \
		--vars-file=gp-continuous-integration/secrets/gpdb-oss-release.prod.yml \
		--vars-file=gp-continuous-integration/secrets/ppa-debian-release-secrets.yml \
		--vars-file=greenplum-database-release/ci/concourse/vars/greenplum-database-release.prod.yml \
		--var=pipeline-name=greenplum-database-release \
		--var=greenplum-database-release-git-branch=master \
		--var=greenplum-database-release-git-remote=https://github.com/greenplum-db/greenplum-database-release.git >interpolated_pipeline
	yq r -j interpolated_pipeline 'resources(name==license_file)' | docker run --interactive -v "${TMP_DIR}"/license_file:/resource frodenas/gcs-resource /opt/resource/in /resource
}
