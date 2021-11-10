#!/usr/bin/env bash

set -eo pipefail
set -x

function set_gpdb_clients_version() {
	GPDB_VERSION=$RELEASE_VERSION
	export GPDB_VERSION
}

function build_deb() {

	local __package_name=$1
	local __gpdb_clients_binary_tarball=$2

	mkdir -p "deb_build_dir"

	pushd "deb_build_dir"
	mkdir -p "${__package_name}/DEBIAN"
	cat <<EOF >"${__package_name}/DEBIAN/postinst"
#!/bin/sh
set -e
cd ${GPDB_PREFIX}/
rm -f ${GPDB_NAME}
ln -s ${GPDB_NAME}-${GPDB_VERSION} ${GPDB_NAME}
cd ${GPDB_NAME}-${GPDB_VERSION}
if [ "${GPDB_MAJOR_VERSION}" = "7" ]; then
	python3 -m compileall -q -x test .
else
	ext/python/bin/python -m compileall -q -x test .
fi
exit 0
EOF
	chmod 0775 "${__package_name}/DEBIAN/postinst"
	cat <<EOF >"${__package_name}/DEBIAN/prerm"
#!/bin/sh
set -e
if [ "${GPDB_MAJOR_VERSION}" = "7" ]; then
	cd ${GPDB_PREFIX}/${GPDB_NAME}-${GPDB_VERSION}
	find . | grep __pycache__ | xargs rm -rf
else
	dpkg -L greenplum-db-clients | grep '\.py$' | while read file; do rm -f "\${file}"[co] >/dev/null; done
fi
exit 0
EOF
	chmod 0775 "${__package_name}/DEBIAN/prerm"
	cat <<EOF >"${__package_name}/DEBIAN/postrm"
#!/bin/sh
set -e
rm -f ${GPDB_PREFIX}/${GPDB_NAME}
exit 0
EOF
	chmod 0775 "${__package_name}/DEBIAN/postrm"

	if [ "${GPDB_MAJOR_VERSION}" = "7" ]; then
		cp "../greenplum-database-release/ci/concourse/scripts/greenplum-db-7-clients-control" "${__package_name}/DEBIAN/control"
	else
		cp "../greenplum-database-release/ci/concourse/scripts/greenplum-db-clients-control" "${__package_name}/DEBIAN/control"
	fi

	sed -i "s|\${GPDB_VERSION}|${GPDB_VERSION}|g" "${__package_name}/DEBIAN/control"

	mkdir -p "${__package_name}/${GPDB_PREFIX}/${GPDB_NAME}-${GPDB_VERSION}"
	tar -xf "../${__gpdb_clients_binary_tarball}" -C "${__package_name}/${GPDB_PREFIX}/${GPDB_NAME}-${GPDB_VERSION}"
	sed -i -e "1 s~^\(GPHOME_CLIENTS=\).*~\1$GPDB_PREFIX/$GPDB_NAME-$GPDB_VERSION~" "${__package_name}/${GPDB_PREFIX}/${GPDB_NAME}-${GPDB_VERSION}/greenplum_clients_path.sh"
	dpkg-deb --build "${__package_name}"
	popd

	cp "deb_build_dir/${__package_name}.deb" gpdb_clients_deb_installer/
}

function _main() {
	local __final_deb_name
	local __final_package_name
	local __built_deb
	local __gpdb_clients_version

	if [[ -z "${GPDB_VERSION}" ]]; then
		set_gpdb_clients_version
	fi
	__gpdb_clients_version="${GPDB_VERSION}"
	echo "[INFO] Building deb installer for GPDB clients version: ${__gpdb_clients_version}"

	echo "[INFO] Building for platform: ${PLATFORM}"

	# Build the expected deb name based on the gpdb clients version of the artifacts
	__final_deb_name="greenplum-db-clients-${__gpdb_clients_version}-${PLATFORM}-amd64.deb"
	echo "[INFO] Final deb name: ${__final_deb_name}"

	# Strip the last .deb from the __final_deb_name
	__final_package_name="${__final_deb_name%.*}"

	# depending on the context in which this script is called, the contents of the `bin_gpdb_clients` directory are slightly different
	# in one case, `bin_gpdb` is expected to contain a file `clients-rc-<semver>-<platform>-<arch>.tar.gz` and in the other
	# case `bin_gpdb_clients` is expected to contain file `bin_gpdb.tar.gz`
	if [[ -f bin_gpdb_clients/bin_gpdb_clients.tar.gz ]]; then
		build_deb "${__final_package_name}" bin_gpdb_clients/bin_gpdb_clients.tar.gz
	else
		build_deb "${__final_package_name}" bin_gpdb_clients/clients-*.tar.gz
	fi

	# Export the built deb and include a sha256 hash
	__built_deb="gpdb_clients_deb_installer/${__final_deb_name}"
	openssl dgst -sha256 "${__built_deb}" >"${__built_deb}".sha256 || exit 1
	echo "[INFO] Final deb installer: ${__built_deb}"
	echo "[INFO] Final deb installer sha: $(cat "${__built_deb}".sha256)" || exit 1
}

_main || exit 1
