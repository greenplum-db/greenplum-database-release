#!/bin/bash

set -eo pipefail
set -x

function build_debian() {

	local __package_name=$1
	local __gpdb_binary_tarbal=$2

	mkdir -p "debian_build_dir"

	pushd "debian_build_dir"
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
	cat <<EOF >"${__package_name}/DEBIAN/copyright"
License: ${GPDB_LICENSE}
EOF
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
    openssh-client,
    openssl,
    perl,
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

	cp "debian_build_dir/${__package_name}.deb" gpdb_debian_installer/
}

function _main() {
	local __final_debian_name
	local __final_package_name
	local __built_debian

	if [[ -z "${GPDB_VERSION}" ]]; then
		export GPDB_VERSION="$(./gpdb_src/getversion --short | grep -Po '^[^+]*')"
	fi
	echo "[INFO] Building debian installer for GPDB version: ${GPDB_VERSION}"

	echo "[INFO] Building for platform: ${PLATFORM}"

	# Build the expected debian name based on the gpdb version of the artifacts
	__final_debian_name="greenplum-db-${GPDB_VERSION}-${PLATFORM}-amd64.deb"
	echo "[INFO] Final debian name: ${__final_debian_name}"

	# Strip the last .deb from the __final_debian_name
	__final_package_name="${__final_debian_name%.*}"
	# Setup a location to build debian

    # compared to gp-integration-testing pipeline, gp-release pipeline has different contents for bin_gpdb directory
    # for gp-integration-testing, say bin_gpdb/server-rc-6.0.0-beta.3+dev.192.g753594a-ubuntu18.04_x86_64.tar.gz
    # while gp-release, say bin_gpdb/QAUtils-ubuntu18.04-amd64.tar.gz and bin_gpdb/bin_gpdb.tar.gz
	if [[ -f bin_gpdb/bin_gpdb.tar.gz ]]; then
        build_debian "${__final_package_name}" bin_gpdb/bin_gpdb.tar.gz
    else
        build_debian "${__final_package_name}" bin_gpdb/server-*.tar.gz
    fi
	# Export the built debian and include a sha256 hash
	__built_debian="gpdb_debian_installer/${__final_debian_name}"
	openssl dgst -sha256 "${__built_debian}" >"${__built_debian}".sha256 || exit 1
	echo "[INFO] Final Debian installer: ${__built_debian}"
	echo "[INFO] Final Debian installer sha: $(cat "${__built_debian}".sha256)" || exit 1
}

_main || exit 1