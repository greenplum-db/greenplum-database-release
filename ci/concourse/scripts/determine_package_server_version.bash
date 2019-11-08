#!/bin/bash

## ======================================================================
# Identify the version of the Server within a given package.
#
#  Currently uses the method of getting the information from the
#  `git-info.json` file that is built into the binary source tree
#  at $PREFIX/etc/ . Supports both RPM and DEB package types.
#
# Usage:
#   ./determine_package_server_version.bash [PACKAGE]
#
## ======================================================================

function usage() {
	echo "Usage:"
	echo "  ./determine_package_server_version.bash [PACKAGE]"
	echo ""
	echo "    Required Parameters"
	echo "      [PACKAGE]:          Path to a valid Server package, e.g. ./greenplum-db.rpm"
	echo ""
}

## ======================================================================
# Install prerequisite
## ======================================================================
# TODO: These should be pre-installed
yum install -y -q epel-release >/dev/null 2>&1
yum install -y -q dpkg >/dev/null 2>&1

## ======================================================================
# Check for prerequisite utilities
## ======================================================================
PREREQ_COMMANDS="dpkg rpm"

for COMMAND in ${PREREQ_COMMANDS}; do
	type "${COMMAND}" >/dev/null 2>&1 || {
		echo >&2 "Required command line utility \"${COMMAND}\" is not available.  Aborting."
		exit 1
	}
done

## ======================================================================
# Verify a package was supplied as an arguement and determine type
## ======================================================================
package="$1"

# Check if command line argument is given and is a file
if [ -z "${1}" ]; then
	usage
	exit 1
elif [ ! -f "${package}" ]; then
	echo ""
	echo "'${package}' is not a file"
	usage
	exit 1
fi

rpm -qp "${package}" >/dev/null 2>&1
is_rpm_package=$?

dpkg -I "${package}" >/dev/null 2>&1
is_deb_package=$?

if [ ! "${is_rpm_package}" -eq 0 ] && [ ! "${is_deb_package}" -eq 0 ]; then
	echo ""
	echo "'${package}' is neither an RPM package nor a DEB package"
	usage
	exit 1
fi

## ======================================================================
# Given package type, determine version
## ======================================================================
if [ "${is_rpm_package}" -eq 0 ]; then
	package_version=$(rpm -qp --queryformat '%{VERSION}' "${package}")
elif [ "${is_deb_package}" -eq 0 ]; then
	package_version=$(dpkg-deb -f "${package}" Version)
fi

echo "${package_version}"
