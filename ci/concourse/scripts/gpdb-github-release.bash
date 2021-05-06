#!/usr/bin/env bash
# Copyright (C) 2019-Present VMware, and affiliates Inc. All rights reserved.
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

GPDB_RELEASE_COMMIT_SHA="$(git --git-dir gpdb_src/.git rev-parse HEAD)"
GPDB_RELEASE_TAG="$(git --git-dir gpdb_src/.git describe --tags "${GPDB_RELEASE_COMMIT_SHA}")"

OUTPUT_DIR="${BASE_DIR}/release_artifacts"

function build_gpdb_binaries_tarball() {
	pushd "${BASE_DIR}/gpdb_src"
	git --no-pager show --summary refs/tags/"${GPDB_RELEASE_TAG}"
	git clean -fdx
	popd

	# Why we do not use the `git archive` command to archive the gpdb source code
	# 1. `git archive` can not archive the submodules parts directly
	# 2. we have one implementation using `git archive`, you can ref:
	# https://github.com/greenplum-db/greenplum-database-release/commit/4e15c018f82f647129ac6e704d4fd0e9a66c353a
	printf "%s build commit:%s\n" "${GPDB_RELEASE_TAG}" "${GPDB_RELEASE_COMMIT_SHA}" >gpdb_src/VERSION
	tar --exclude '.git*' -czf "${OUTPUT_DIR}/${GPDB_RELEASE_TAG}-src-full.tar.gz" gpdb_src
	zip -r -q "${OUTPUT_DIR}/${GPDB_RELEASE_TAG}-src-full.zip" gpdb_src -x '*.git*'
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
