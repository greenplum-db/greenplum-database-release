#!/bin/bash
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

set -eo pipefail
set -x

function set_gpdb_version_from_source() {
  GPDB_VERSION=$(./gpdb_src/getversion --short | grep -Po '^[^+]*')
  export GPDB_VERSION
}

function set_gpdb_version_from_binary() {
  apt-get update
  apt-get install -y jq

  GPDB_VERSION="$(tar xzf bin_gpdb/*.tar.gz -O ./etc/git-info.json | jq -r '.root.version')"
  export GPDB_VERSION
}

function build_deb() {
  apt-get update -q=2
  apt-get install -q=2 -y software-properties-common debmake equivs git
  python3 greenplum-database-release/concourse/scripts/publish_to_ppa.py

  cp ./*.deb  gpdb_deb_installer/
}

function _main() {
	local __final_deb_name
	local __final_package_name
	local __built_deb

	if [[ -d gpdb_src ]]; then
		set_gpdb_version_from_source
	elif [[ -d bin_gpdb ]]; then
		set_gpdb_version_from_binary
	else
		echo "[FATAL] Missing gpdb_src and bin_gpdb; needed to set GPDB_VERSION"
		exit 1
	fi
	echo "[INFO] Building deb installer for GPDB version: ${GPDB_VERSION}"

	echo "[INFO] Building for platform: ${PLATFORM}"

	# Build the expected deb name based on the gpdb version of the artifacts
	__final_deb_name="greenplum-db-${GPDB_VERSION}-${PLATFORM}-amd64.deb"
	echo "[INFO] Final deb name: ${__final_deb_name}"

	# Strip the last .deb from the __final_deb_name
	__final_package_name="${__final_deb_name%.*}"
	
	# depending on the context in which this script is called, the contents of the `bin_gpdb` directory are slightly different
	# in one case, `bin_gpdb` is expected to contain a file `server-rc-<semver>-<platform>-<arch>.tar.gz` and in the other
	# case `bin_gpdb` is expected to contain files `bin_gpdb.tar.gz` and `QAUtils-<platform>-<arch>.tar.gz`
	if [[ -f bin_gpdb/bin_gpdb.tar.gz ]]; then
		build_deb "${__final_package_name}" bin_gpdb/bin_gpdb.tar.gz
    	else
		build_deb "${__final_package_name}" bin_gpdb/server-*.tar.gz
	fi
	# Export the built deb and include a sha256 hash
	__built_deb="gpdb_deb_installer/${__final_deb_name}"
	openssl dgst -sha256 "${__built_deb}" >"${__built_deb}".sha256 || exit 1
	echo "[INFO] Final Debian installer: ${__built_deb}"
	echo "[INFO] Final Debian installer sha: $(cat "${__built_deb}".sha256)" || exit 1
}

_main || exit 1
