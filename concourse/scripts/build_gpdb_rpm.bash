#!/bin/bash

die() {
  echo "$*" >/dev/stderr
  exit 1
}

function set_gpdb_version_from_source() {
  GPDB_VERSION=$(./gpdb_src/getversion --short | grep -Po '^[^+]*')
  export GPDB_VERSION
}

function set_gpdb_version_from_binary() {
  yum install -d0 -y epel-release
  yum install -d0 -y jq

  GPDB_VERSION="$(tar xzf bin_gpdb/*.tar.gz -O ./etc/git-info.json | jq -r '.root.version')"
  export GPDB_VERSION
}

function determine_rpm_build_dir() {
  local __rpm_build_dir
  local __platform

  __platform=$1

  case "${__platform}" in
      rhel*) __rpm_build_dir=/root/rpmbuild ;;
      *)     die "Unsupported platform: '${__platform}'. only rhel* is supported" ;;
  esac

  echo "${__rpm_build_dir}"
}

function setup_rpm_buildroot() {
  local __rpm_build_dir="${1}"
  local __gpdb_binary_tarbal="${2}"

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
  declare -A __possible_flags=()
  __possible_flags+=(["GPDB_NAME"]="${GPDB_NAME}")
  __possible_flags+=(["GPDB_SUMMARY"]="${GPDB_SUMMARY}")
  __possible_flags+=(["GPDB_LICENSE"]="${GPDB_LICENSE}")
  __possible_flags+=(["GPDB_URL"]="${GPDB_URL}")
  __possible_flags+=(["GPDB_BUILDARCH"]="${GPDB_BUILDARCH}")
  __possible_flags+=(["GPDB_DESCRIPTION"]="${GPDB_DESCRIPTION}")
  __possible_flags+=(["GPDB_PREFIX"]="${GPDB_PREFIX}")

  # The gpdb_version and rpm_gpdb_version are always required
  __rpm_build_flags="--define=\"rpm_gpdb_version ${__rpm_gpdb_version}\""
  __rpm_build_flags="${__rpm_build_flags} --define=\"gpdb_version ${__gpdb_version}\""
  __rpm_build_flags="${__rpm_build_flags} --define=\"gpdb_release ${GPDB_RELEASE}\""

  # Only loops over flags that are defined (non zero size)
  for key in "${!__possible_flags[@]}"
  do
      value="${__possible_flags[${key}]}"
      if [ ! -z "${value}" ] ; then
        # The SPEC file assumes all lowercase macro names
        key_lowercase=$(echo "${key}" | tr '[:upper:]' '[:lower:]')
        __rpm_build_flags="${__rpm_build_flags} --define=\"${key_lowercase} ${value}\""
      else
        echo "Should provide ${key}"
        exit 1
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

  if [[ -d gpdb_src ]]; then
    set_gpdb_version_from_source
  elif [[ -d bin_gpdb ]]; then
    set_gpdb_version_from_binary
  else
    echo "[FATAL] Missing gpdb_src and bin_gpdb; needed to set GPDB_VERSION"
    exit 1
  fi
  __gpdb_version=$(echo ${GPDB_VERSION})
  echo "[INFO] Building rpm installer for GPDB version: ${__gpdb_version}"

  echo "[INFO] Building for platform: ${PLATFORM}"

  # RPM Versions cannot have a '-'. The '-' is reserved by SPEC to denote %{version}-%{release}
  __rpm_gpdb_version=$(echo "${__gpdb_version}" | tr '-' '_' )
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
  cp greenplum-database-release/concourse/scripts/greenplum-db.spec "${__rpm_build_dir}/SPECS/greenplum-db.spec"

  # Generate the flags for building the RPM based on pipeline values
  __rpm_build_flags=$(create_rpmbuild_flags "${__gpdb_version}" "${__rpm_gpdb_version}")

  echo "[INFO] RPM build flags: ${__rpm_build_flags}"

  # Build the RPM
  # TODO: Is the eval actually necessary?
  eval "rpmbuild -bb ${__rpm_build_dir}/SPECS/greenplum-db.spec ${__rpm_build_flags}" || exit 1

  # Export the built RPM and include a sha256 hash
  __built_rpm="gpdb_rpm_installer/${__final_rpm_name}"
  cp "${__rpm_build_dir}"/RPMS/x86_64/greenplum-*.rpm "${__built_rpm}"
  openssl dgst -sha256 "${__built_rpm}" > "${__built_rpm}".sha256 || exit 1
  echo "[INFO] Final RPM installer: ${__built_rpm}"
  echo "[INFO] Final RPM installer sha: $(cat "${__built_rpm}".sha256)" || exit 1
}

_main || exit 1
