#!/bin/bash

BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
	echo "$*" >/dev/stderr
	exit 1
}

function set_gpdb_version() {
	GPDB_VERSION=$(./gpdb_src/getversion --short | grep -Po '^[^+]*')
	export GPDB_VERSION
}

function determine_rpm_build_dir() {
	local __rpm_build_dir
	local __platform

	__platform=$1

	case "${__platform}" in
	sles*) __rpm_build_dir=/usr/src/packages ;;
	rhel*) __rpm_build_dir=/root/rpmbuild ;;
	*) die "Unsupported platform: '${__platform}'. sles* and rhel* are supported" ;;
	esac

	echo "${__rpm_build_dir}"
}

function setup_rpm_buildroot() {
	local __rpm_build_dir
	local __gpdb_binary_tarbal

	__rpm_build_dir=$1
	__gpdb_binary_tarbal=$2

	mkdir -p "${__rpm_build_dir}"/{SOURCES,SPECS}
	cp "${__gpdb_binary_tarbal}" "${__rpm_build_dir}/SOURCES/gpdb.tar.gz"
}

# Craft the arguments to pass to rpmbuild based on what is defined, or not
# defined in environment variables from the pipeline
function create_rpmbuild_flags() {
	local __gpdb_version
	local __rpm_build_flags
	local __possible_flags

	__gpdb_version=$1
	__rpm_gpdb_version=$2

	# The following are the possible params (environment variables):
	# If variable is not defined, it wont be added to the array on instantiation
	__possible_flags=(GPDB_RELEASE GPDB_LICENSE GPDB_URL)

	# This most explicitly be unset in order to allow ${!var} to reflect a
	# variables value from it's name
	set +u

	# The gpdb_version and rpm_gpdb_version are always required
	__rpm_build_flags="--define=\"rpm_gpdb_version ${__rpm_gpdb_version}\""
	__rpm_build_flags="${__rpm_build_flags} --define=\"gpdb_version ${__gpdb_version}\""

	# Only loops over flags that are defined (non zero size)
	for i in "${__possible_flags[@]}"; do
		# The ${!var} returns the value of the variable named by the string
		# "var", which in this case is the element i of the above list
		if [ -n "${!i}" ]; then
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
	local __gpdb_version
	local __rpm_gpdb_version
	local __final_rpm_name
	local __rpm_build_flags

	if [[ -z "${GPDB_VERSION}" ]]; then
		set_gpdb_version
	fi
	__gpdb_version="${GPDB_VERSION}"
	echo "[INFO] Building rpm installer for GPDB version: ${__gpdb_version}"

	echo "[INFO] Building for platform: ${PLATFORM}"

	# RPM Versions cannot have a '-'. The '-' is reserved by SPEC to denote %{version}-%{release}
	__rpm_gpdb_version=$(echo "${__gpdb_version}" | tr '-' '_')
	echo "[INFO] GPDB version modified for rpm requirements: ${__rpm_gpdb_version}"

	# Build the expected rpm name based on the gpdb version of the artifacts
	__final_rpm_name="greenplum-db-${__gpdb_version}-${PLATFORM}-x86_64.rpm"
	echo "[INFO] Final RPM name: ${__final_rpm_name}"

	# Conventional location to build RPMs is platform specific
	__rpm_build_dir=$(determine_rpm_build_dir "${PLATFORM}")
	echo "[INFO] RPM build dir: ${__rpm_build_dir}"

	# Setup a location to build RPMs
	setup_rpm_buildroot "${__rpm_build_dir}" "bin_gpdb/bin_gpdb.tar.gz"

	# The spec file must be in the RPM building location
	cp "${BASEDIR}/${GPDB_NAME}.spec" "${__rpm_build_dir}/SPECS/${GPDB_NAME}.spec"

	# Generate the flags for building the RPM based on pipeline values
	__rpm_build_flags=$(create_rpmbuild_flags "${__gpdb_version}" "${__rpm_gpdb_version}")

	echo "[INFO] RPM build flags: ${__rpm_build_flags}"

	# Build the RPM
	# TODO: Is the eval actually necessary?
	eval "rpmbuild -bb ${__rpm_build_dir}/SPECS/${GPDB_NAME}.spec ${__rpm_build_flags}" || exit 1

	# Export the built RPM and include a sha256 hash
	__built_rpm="gpdb_rpm_installer/${__final_rpm_name}"
	cp "${__rpm_build_dir}"/RPMS/x86_64/greenplum-db-*.rpm "${__built_rpm}"
	openssl dgst -sha256 "${__built_rpm}" >"${__built_rpm}".sha256 || exit 1
	echo "[INFO] Final RPM installer: ${__built_rpm}"
	echo "[INFO] Final RPM installer sha: $(cat "${__built_rpm}.sha256")" || exit 1
}

_main || exit 1
