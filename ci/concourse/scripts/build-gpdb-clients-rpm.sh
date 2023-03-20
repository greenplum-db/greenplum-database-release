#!/bin/bash
#inputs:
#- name: bin_gpdb_clients
#- name: greenplum-database-release
#- name: gpdb_src
#outputs:
#- name: gpdb_clients_rpm_installer
#params:
#  PLATFORM:
#  # Default values passed to rpm SPEC
#  #  To override, please do so in pipeline
#  GPDB_CLIENTS_NAME: greenplum-db-clients
#  GPDB_CLIENTS_SUMMARY: Greenplum-DB-Clients
#  GPDB_CLIENTS_LICENSE: VMware Software EULA
#  GPDB_CLIENTS_URL: https://network.tanzu.vmware.com/products/vmware-greenplum/
#  GPDB_CLIEBTS_BUILDARCH: x86_64
#  GPDB_CLIENTS_DESCRIPTION: Greenplum Database Clients
#  GPDB_CLIENTS_PREFIX: /usr/local

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
	echo "$*" >/dev/stderr
	exit 1
}

function set_gpdb_clients_version() {
	# shellcheck disable=SC2155
	export GPDB_VERSION=$RELEASE_VERSION

	# shellcheck disable=SC2154
	# shellcheck disable=SC2155
	export GPDB_RELEASE=$(echo "$version" | grep -o '^[^\.]*')
}

function determine_rpm_build_dir() {
	local __rpm_build_dir
	local __platform

	__platform=$1

	case "${__platform}" in
	sles*) __rpm_build_dir=/usr/src/packages ;;
	rhel*) __rpm_build_dir=/root/rpmbuild ;;
	photon*) __rpm_build_dir=/usr/src/photon ;;
	rocky*) __rpm_build_dir=/root/rpmbuild ;;
	oel*) __rpm_build_dir=/root/rpmbuild ;;
	*) die "Unsupported platform: '${__platform}'. sles*, rhel*, photon*, rocky*, oel* are supported" ;;
	esac

	echo "${__rpm_build_dir}"
}

function setup_rpm_buildroot() {
	local __rpm_build_dir
	local __gpdb_binary_tarbal

	__rpm_build_dir=$1
	__gpdb_binary_tarbal=$2

	mkdir -p "${__rpm_build_dir}"/{SOURCES,SPECS}
	cp "${__gpdb_binary_tarbal}" "${__rpm_build_dir}/SOURCES/gpdb_clients.tar.gz"
}

# Craft the arguments to pass to rpmbuild based on what is defined, or not
# defined in environment variables from the pipeline
function create_rpmbuild_flags() {
	local __gpdb_clients_version
	# shellcheck disable=SC2034
	local __rpm_version
	local __rpm_build_flags
	local __possible_flags

	__gpdb_clients_version=$1
	__rpm_gpdb_clients_version=$2

	# The following are the possible params (environment variables):
	# If variable is not defined, it wont be added to the array on instantiation
	__possible_flags=(GPDB_CLIENTS_NAME GPDB_RELEASE GPDB_CLIENTS_SUMMARY GPDB_CLIENTS_LICENSE GPDB_CLIENTS_URL GPDB_CLIENTS_BUILDARCH GPDB_CLIENTS_DESCRIPTION GPDB_CLIENTS_PREFIX)

	# This most explicitly be unset in order to allow ${!var} to reflect a
	# variables value from it's name
	set +u

	# The gpdb_clients_version and rpm_gpdb_clients_version are always required
	__rpm_build_flags="--define=\"rpm_gpdb_clients_version ${__rpm_gpdb_clients_version}\""
	__rpm_build_flags="${__rpm_build_flags} --define=\"gpdb_clients_version ${__gpdb_clients_version}\""

	# Only loops over flags that are defined (non zero size)
	for i in "${__possible_flags[@]}"; do
		# The ${!var} returns the value of the variable named by the string
		# "var", which in this case is the element i of the above list
		# shellcheck disable=SC2236
		if [ ! -z "${!i}" ]; then
			# The SPEC file assumes all lowercase macro names
			i_lowercase=$(echo "${i}" | tr '[:upper:]' '[:lower:]')
			__rpm_build_flags="${__rpm_build_flags} --define=\"${i_lowercase} ${!i}\""
		fi
	done

	echo "${__rpm_build_flags}"
}

function _main() {
	local __built_rpm
	local __rpm_build_dir
	local __gpdb_clients_version
	local __rpm_gpdb_clients_version
	local __final_rpm_name
	local __rpm_build_flags
	local __platform

	if [[ -z "${GPDB_VERSION}" ]]; then
		set_gpdb_clients_version
	fi
	__gpdb_clients_version="${GPDB_VERSION}"
	echo "[INFO] Building rpm installer for GPDB version: ${__gpdb_clients_version}"

	echo "[INFO] Building for platform: ${PLATFORM}"

	# RPM Versions cannot have a '-'. The '-' is reserved by SPEC to denote %{version}-%{release}
	__rpm_gpdb_clients_version=$(echo "${__gpdb_clients_version}" | tr '-' '_')
	echo "[INFO] GPDB version modified for rpm requirements: ${__rpm_gpdb_clients_version}"

	# Build the expected rpm name based on the gpdb version of the artifacts
	__platform="${PLATFORM}"
	case "${__platform}" in
	rhel8*) __final_rpm_name="greenplum-db-clients-${__gpdb_clients_version}-el8-x86_64.rpm" ;;
	rocky8*) __final_rpm_name="greenplum-db-clients-${__gpdb_clients_version}-el8-x86_64.rpm" ;;
	oel8*) __final_rpm_name="greenplum-db-clients-${__gpdb_clients_version}-el8-x86_64.rpm" ;;
	*) __final_rpm_name="greenplum-db-clients-${__gpdb_clients_version}-${PLATFORM}-x86_64.rpm" ;;
	esac
	echo "[INFO] Final RPM name: ${__final_rpm_name}"

	# Conventional location to build RPMs is platform specific
	__rpm_build_dir=$(determine_rpm_build_dir "${PLATFORM}")
	echo "[INFO] RPM build dir: ${__rpm_build_dir}"

	# Setup a location to build RPMs
	setup_rpm_buildroot "${__rpm_build_dir}" bin_gpdb_clients/*.tar.gz

	# The spec file must be in the RPM building location
	if [[ "${GPDB_MAJOR_VERSION}" == 7 ]]; then
		cp "${BASEDIR}/gpdb-7-clients.spec" "${__rpm_build_dir}"/SPECS/gpdb-clients.spec
	else
		cp "${BASEDIR}/gpdb-clients.spec" "${__rpm_build_dir}"/SPECS/gpdb-clients.spec
	fi

	# Generate the flags for building the RPM based on pipeline values
	__rpm_build_flags=$(create_rpmbuild_flags "${__gpdb_clients_version}" "${__rpm_gpdb_clients_version}")

	echo "[INFO] RPM build flags: ${__rpm_build_flags}"

	# Build the RPM
	# TODO: Is the eval actually necessary?
	eval "rpmbuild -bb ${__rpm_build_dir}/SPECS/gpdb-clients.spec ${__rpm_build_flags}" || exit 1

	# Export the built RPM and include a sha256 hash
	__built_rpm="gpdb_clients_rpm_installer/${__final_rpm_name}"
	cp "${__rpm_build_dir}"/RPMS/x86_64/greenplum-db-*.rpm "${__built_rpm}"
	openssl dgst -sha256 "${__built_rpm}" >"${__built_rpm}".sha256 || exit 1
	echo "[INFO] Final RPM installer: ${__built_rpm}"
	echo "[INFO] Final RPM installer sha: $(cat "${__built_rpm}".sha256)" || exit 1
}

_main || exit 1
