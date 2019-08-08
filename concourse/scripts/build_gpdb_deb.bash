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

	local __package_name=$1
	local __gpdb_binary_tarbal=$2

	mkdir -p "deb_build_dir"

	pushd "deb_build_dir"
	mkdir -p "${__package_name}/DEBIAN"
	cat <<EOF >"${__package_name}/DEBIAN/postinst"
#!/bin/sh
set -e
cd ${GPDB_PREFIX}/
rm -f ${GPDB_NAME}
ln -s ${GPDB_NAME}-${GPDB_VERSION} ${GPDB_NAME}
exit 0
EOF
	chmod 0775 "${__package_name}/DEBIAN/postinst"
	cat <<EOF >"${__package_name}/DEBIAN/postrm"
#!/bin/sh
set -e
rm -f ${GPDB_PREFIX}/${GPDB_NAME}
exit 0
EOF
	chmod 0775 "${__package_name}/DEBIAN/postrm"
	mkdir -p "${__package_name}/usr/share/doc/greenplum-db/"
	if [ -d ../license_file ]; then
	    cp ../license_file/*.txt "${__package_name}/usr/share/doc/greenplum-db/open_source_license_greenplum_database.txt"
	fi

	if [[ "${GPDB_OSS}" == 'true' ]];then
		SHARE_DOC_ROOT="${__package_name}/usr/share/doc/greenplum-db"

		cp ../gpdb_src/LICENSE "${SHARE_DOC_ROOT}/LICENSE"
		cp ../gpdb_src/COPYRIGHT "${SHARE_DOC_ROOT}/COPYRIGHT"

		cat <<NOTICE_EOF >"${SHARE_DOC_ROOT}/NOTICE"
Greenplum Database

Copyright (c) 2019 Pivotal Software, Inc. All Rights Reserved.

This product is licensed to you under the Apache License, Version 2.0 (the "License").
You may not use this product except in compliance with the License.

This product may include a number of subcomponents with separate copyright notices
and license terms. Your use of these subcomponents is subject to the terms and
conditions of the subcomponent's license, as noted in the LICENSE file.
NOTICE_EOF
	else
		echo "Pivotal EUAL file is here!"
		# TODO: Pivotal EUAL file should be here!
	fi

	cat <<EOF >"${__package_name}/DEBIAN/control"
Package: greenplum-db
Priority: extra
Maintainer: gp-releng@pivotal.io
Architecture: ${GPDB_BUILDARCH}
Version: ${GPDB_VERSION}
Provides: Pivotal
Description: ${GPDB_DESCRIPTION}
Homepage: ${GPDB_URL}
Depends: libapr1,
    libaprutil1,
    bash,
    bzip2,
    krb5-multidev,
    libcurl3-gnutls,
    libcurl4,
    libedit2,
    libevent-2.1-6,
    libxml2,
    libyaml-0-2,
    zlib1g,
    libldap-2.4-2,
    openssh-client,
    openssh-server,
    openssl,
    perl,
    rsync,
    sed,
    tar,
    zip,
    net-tools,
    less,
    iproute2
EOF

	mkdir -p "${__package_name}/${GPDB_PREFIX}/${GPDB_NAME}-${GPDB_VERSION}"
	tar -xf "../${__gpdb_binary_tarbal}" -C "${__package_name}/${GPDB_PREFIX}/${GPDB_NAME}-${GPDB_VERSION}"
	sed -i -e "1 s~^\(GPHOME=\).*~\1$GPDB_PREFIX/$GPDB_NAME-$GPDB_VERSION~" "${__package_name}/${GPDB_PREFIX}/${GPDB_NAME}-${GPDB_VERSION}/greenplum_path.sh"
	dpkg-deb --build "${__package_name}"
	popd

	cp "deb_build_dir/${__package_name}.deb" gpdb_deb_installer/
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
