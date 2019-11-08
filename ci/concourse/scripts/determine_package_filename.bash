#!/bin/bash

## ======================================================================
# Determine the correct filename to use for a package given user supplied
#  information and the current business logic for how to compose that
#  information into a package name.
#
#  Business filename convention:
#   [Product Shortname]-[Version]-[Platform][Platform Major Version]-[Arch].[Package Type]
#
# Usage:
#   ./determine_package_filename.bash [Version]
#
## ======================================================================

function usage() {
	echo "Usage:"
	echo "  ./determine_package_filename.bash [Shortname] [Version] [Platform] [Platform Version]"
	echo ""
	echo "    Required Parameters"
	echo "      [Shortname]:          Shortname of the product, e.g. greenplum-db"
	echo "      [Version]:            Semi-semantic version of the product release, e.g. 6.0.0"
	echo "      [Platform]:           Platform the package supports, e.g. Redhat, Centos, Ubuntu"
	echo "      [Platform Version]:   Version of the platform the package supports e.g. 6.0.0"
	echo ""
}

## ======================================================================
# Input validation
## ======================================================================
package_shortname="${1}"
package_version="${2}"
package_platform="${3}"
package_platform_version="${4}"

# Check for all inputs
if [ -z "${1}" ] || [ -z "${2}" ] || [ -z "${3}" ] || [ -z "${4}" ]; then
	usage
	exit 1
fi

# TODO: Validation that the versions are valid semi-semantic.
#  There is no bash library for this and versions for things like
#  platform versions are typically MAJOR.MINOR

## ======================================================================
# Input Sanitization
## ======================================================================
# Make everything lowercase
package_shortname=$(echo "${package_shortname}" | tr '[:upper:]' '[:lower:]')
package_platform=$(echo "${package_platform}" | tr '[:upper:]' '[:lower:]')

## ======================================================================
# Calcuated filename conventions
## ======================================================================
if [[ "${package_platform}" =~ redhat|rhel|centos ]]; then
	package_platform="rhel"
elif [[ "${package_platform}" =~ ubuntu ]]; then
	package_type="ubuntu"
else
	echo "Error: Package platform '${package_platform}' is not implimented"
	usage
	exit 1
fi

if [ "${package_platform}" == "rhel" ]; then
	package_type="rpm"
	package_arch="x86_64"
	# The platform version for rhel platforms is typically specifed like this:
	#  rhel7, rhel8 or el6, el7.
	# In following that convention, we only care about the Major version component
	package_platform_major_version=$(echo "${package_platform_version}" | cut -d"." -f1)
elif [ "${package_platform}" == "ubuntu" ]; then
	package_type="deb"
	package_arch="amd64"
	# The platform version for ubuntu platforms typically follows LTS releases:
	#  ubuntu18.04, ubuntu16.04
	# In following that convention, we only let expect user specify the whole version
	#  and let input validation error out if it's not a MAJOR.MINOR version schema
	package_platform_major_version="${package_platform_version}"
fi

echo "${package_shortname}-${package_version}-${package_platform}${package_platform_major_version}-${package_arch}.${package_type}"
