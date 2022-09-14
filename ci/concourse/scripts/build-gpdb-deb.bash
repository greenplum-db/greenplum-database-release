#!/bin/bash
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

set -eo pipefail
set -x

function set_gpdb_version_from_binary() {
	apt-get update
	apt-get install -y jq

	GPDB_VERSION="$(tar xzf bin_gpdb/*.tar.gz -O ./etc/git-info.json | jq -r '.root.version')"
	export GPDB_VERSION
}

function build_deb() {

	local __package_name=$1
	local __gpdb_binary_tarbal=$2
	DEB_DIR="DEBIAN"
	doc_dir="usr/share/doc/greenplum-db"
	gpdb_major_version="$(echo "${GPDB_VERSION}" | cut -d '.' -f1)"

	mkdir -p "deb_build_dir"

	pushd "deb_build_dir"
	if [[ "${PPA}" == 'true' ]]; then
		__package_name="greenplum-db-${gpdb_major_version}-${GPDB_VERSION}"
		DEB_DIR="debian"
		revision_number=1
		mkdir -p "${__package_name}/bin_gpdb"
		tar -xf "../${__gpdb_binary_tarbal}" -C "${__package_name}/bin_gpdb"
		tar cvzf greenplum-db-${gpdb_major_version}_${GPDB_VERSION}.orig.tar.gz ${__package_name}
		doc_dir="doc_files"
	fi
	mkdir -p "${__package_name}/${DEB_DIR}"
	cat <<EOF >"${__package_name}/${DEB_DIR}/prerm"
#!/bin/sh
set -e
if [ "${gpdb_major_version}" = "7" ]; then
	cd ${GPDB_PREFIX}/${GPDB_NAME}-${GPDB_VERSION}
	find . | grep __pycache__ | xargs rm -rf
else
	dpkg -L "greenplum-db-${gpdb_major_version}" | grep '\.py$' | while read file; do rm -f "\${file}"[co] >/dev/null; done
fi
exit 0
EOF
	chmod 0775 "${__package_name}/${DEB_DIR}/prerm"
	mkdir -p "${__package_name}/${doc_dir}"
	if [ -d ../license_file ]; then
		if [[ "${GPDB_OSS}" == 'true' ]]; then
			cp ../license_file/*.txt "${__package_name}/${doc_dir}/open_source_license_greenplum_database.txt"
		else
			cp ../license_file/*.txt "${__package_name}/${doc_dir}/open_source_licenses.txt"
		fi
	fi

	if [[ "${GPDB_OSS}" == 'true' ]]; then
		SHARE_DOC_ROOT="${__package_name}/${doc_dir}"

		cp ../gpdb_src/LICENSE "${SHARE_DOC_ROOT}/LICENSE"
		cp ../gpdb_src/COPYRIGHT "${SHARE_DOC_ROOT}/COPYRIGHT"

		cat <<NOTICE_EOF >"${SHARE_DOC_ROOT}/NOTICE"
Greenplum Database

Copyright (c) 2019 VMware, and affiliates Inc. All Rights Reserved.

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

	if [[ "${PPA}" == 'true' ]]; then
		cp "../greenplum-database-release/ci/concourse/scripts/greenplum-db-${gpdb_major_version}-ppa-control" "${__package_name}/${DEB_DIR}/control"
		cat <<EOF >"${__package_name}/${DEB_DIR}/compat"
9
EOF
		cat <<EOF >"${__package_name}/${DEB_DIR}/rules"
#!/usr/bin/make -f

include /usr/share/dpkg/default.mk

%:
	dh \$@ --parallel

# debian policy is to not use /usr/local
# dh_usrlocal does some funny stuff; override to do nothing
override_dh_usrlocal:

# skip scanning for shlibdeps?
override_dh_shlibdeps:

# skip removing debug output
override_dh_strip:
EOF
		cat <<EOF >"${__package_name}/${DEB_DIR}/install"
bin_gpdb/* /opt/greenplum-db-${GPDB_VERSION}
doc_files/* /usr/share/doc/greenplum-db/
EOF
		chmod -x "${__package_name}/${DEB_DIR}/install"
		cat <<EOF >"${__package_name}/${DEB_DIR}/postinst"
#!/bin/sh
set -e
cd /opt/greenplum-db-${GPDB_VERSION}
ext/python/bin/python -m compileall -q -x "(test|python3)" .
exit 0
EOF
		chmod 0775 "${__package_name}/${DEB_DIR}/postinst"
		pushd ${__package_name}
		dch --create --package greenplum-db-${gpdb_major_version} --newversion "${GPDB_VERSION}"-${revision_number} "${RELEASE_MESSAGE}"
		dch --release "ignored message"
		debuild --unsigned-changes --unsigned-source --build=binary
		debuild -S -sa
		popd
		cp "greenplum-db-${gpdb_major_version}_${GPDB_VERSION}-${revision_number}_amd64.deb" ../gpdb_deb_ppa_installer/
		if [[ "${PUBLISH_PPA}" == 'true' ]]; then
			dput "${PPA_REPO}" greenplum-db-${gpdb_major_version}_${GPDB_VERSION}-${revision_number}_source.changes
		fi

		cat <<EOF >"../ppa_release/version.txt"
${GPDB_VERSION}-${revision_number}
EOF
	else
		cat <<EOF >"${__package_name}/${DEB_DIR}/postinst"
#!/bin/sh
set -e
cd ${GPDB_PREFIX}/
rm -f ${GPDB_NAME}
ln -s ${GPDB_PREFIX}/${GPDB_NAME}-${GPDB_VERSION} ${GPDB_NAME}
cd ${GPDB_NAME}-${GPDB_VERSION}
if [ "${gpdb_major_version}" = "7" ]; then
	python3 -m compileall -q -x test .
else
	ext/python/bin/python -m compileall -q -x "(test|python3)" .
fi
exit 0
EOF
		chmod 0775 "${__package_name}/${DEB_DIR}/postinst"
		cat <<EOF >"${__package_name}/${DEB_DIR}/postrm"
#!/bin/sh
set -e
rm -f ${GPDB_PREFIX}/${GPDB_NAME}
exit 0
EOF
		chmod 0775 "${__package_name}/${DEB_DIR}/postrm"
		cp "../greenplum-database-release/ci/concourse/scripts/greenplum-db-${gpdb_major_version}-control" "${__package_name}/${DEB_DIR}/control"

		sed -i "s|\${GPDB_VERSION}|${GPDB_VERSION}|g" "${__package_name}/${DEB_DIR}/control"
		mkdir -p "${__package_name}/${GPDB_PREFIX}/${GPDB_NAME}-${GPDB_VERSION}"
		tar -xf "../${__gpdb_binary_tarbal}" -C "${__package_name}/${GPDB_PREFIX}/${GPDB_NAME}-${GPDB_VERSION}"
		dpkg-deb --build "${__package_name}"
		cp "${__package_name}.deb" ../gpdb_deb_installer/

	fi
	popd

}

function _main() {
	local __final_deb_name
	local __final_package_name
	local __built_deb

	set_gpdb_version_from_binary

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
		build_deb "${__final_package_name}" bin_gpdb/*.tar.gz
	fi
	if [[ "${PPA}" != 'true' ]]; then
		# Export the built deb and include a sha256 hash
		__built_deb="gpdb_deb_installer/${__final_deb_name}"
		openssl dgst -sha256 "${__built_deb}" >"${__built_deb}".sha256 || exit 1
		echo "[INFO] Final Debian installer: ${__built_deb}"
		echo "[INFO] Final Debian installer sha: $(cat "${__built_deb}".sha256)" || exit 1
	fi
}

_main || exit 1
