#!/usr/bin/env bash
# Copyright (C) 2019-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the
# terms of the under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain a
# copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

set -euo pipefail

apk update && apk add --no-progress git tar zip

BASE_DIR="$(pwd)"

GPDB_RELEASE_COMMIT_SHA="$(cat gpdb_src/.git/ref)"
GPDB_RELEASE_TAG="$(git --git-dir gpdb_src/.git describe --tags "${GPDB_RELEASE_COMMIT_SHA}")"

PACKAGE="gpdb"
OUTPUT_DIR="${BASE_DIR}/release_artifacts"
ARCHIVE_TMP_DIR="${BASE_DIR}/source_tmp"
ARCHIVE_TMP_EXTRACT_DIR="${ARCHIVE_TMP_DIR}/extract"

function build_gpdb_binaries_tarball() {
	rm -rf "${ARCHIVE_TMP_DIR}" && mkdir -p "${ARCHIVE_TMP_EXTRACT_DIR}"

	pushd "${BASE_DIR}/gpdb_src"
	git --no-pager show --summary refs/tags/"${GPDB_RELEASE_TAG}"

	git archive --prefix "${PACKAGE}-${GPDB_RELEASE_TAG}/" --format "tar" --output "${ARCHIVE_TMP_DIR}/gpdb_src.tar" HEAD
	git submodule foreach --recursive "echo \$displaypath: \$sha1: \$toplevel;
	git archive --prefix=${PACKAGE}-${GPDB_RELEASE_TAG}/\$displaypath/ \
		--format tar \$sha1 \
		--output $ARCHIVE_TMP_DIR/submodule-\$sha1.tar"

	# Extract all the compressed package to one location.
	tar -C "${ARCHIVE_TMP_EXTRACT_DIR}" -xf "${ARCHIVE_TMP_DIR}/gpdb_src.tar"
	for tar_file in "${ARCHIVE_TMP_DIR}"/submodule*.tar; do
		tar -C "${ARCHIVE_TMP_EXTRACT_DIR}" -xf "${tar_file}"
	done
	popd

	# repackage all things.
	pushd "${ARCHIVE_TMP_EXTRACT_DIR}"
	tar -czf "${OUTPUT_DIR}/${PACKAGE}-${GPDB_RELEASE_TAG}-full.tar.gz" \
		"${PACKAGE}-${GPDB_RELEASE_TAG}"
	zip -r -q "${OUTPUT_DIR}/${PACKAGE}-${GPDB_RELEASE_TAG}-full.zip" "${PACKAGE}-${GPDB_RELEASE_TAG}"
	popd

	echo "Created the release binaries successfully! [tar.gz, zip]"
}

function create_github_release_metadata() {
	# Prepare for the gpdb github release
	echo "${GPDB_RELEASE_TAG}" >"release_artifacts/name"
	echo "${GPDB_RELEASE_TAG}" >"release_artifacts/tag"
	echo "Greenplum-db version: ${GPDB_RELEASE_TAG}" >"release_artifacts/body"
	echo "${GPDB_RELEASE_COMMIT_SHA}" >release_artifacts/commitish
}

function _main() {
	echo "Current Released Tag: ${GPDB_RELEASE_TAG}"

	build_gpdb_binaries_tarball
	create_github_release_metadata
}

_main
