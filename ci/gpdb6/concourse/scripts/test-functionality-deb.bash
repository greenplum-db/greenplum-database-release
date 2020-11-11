#!/bin/bash
set -exo pipefail

if [[ ${PLATFORM} != "ubuntu"* ]]; then
	echo "This script only supports testing Ubuntu deb packages"
	exit 1
fi

pushd gpdb_deb_installer

# shellcheck disable=SC2035
test -n "$(dpkg-deb --field *.deb Homepage)"

# Test gpdb deb package is installable
apt-get --quiet update && apt-get install --quiet=8 --yes "${PWD}"/*.deb

# Test /usr/local/greenplum-db is a link to greenplum-db-#{gpdb_version}
# shellcheck disable=SC2035
GPDB_VERSION="$(dpkg-deb --field *.deb Version)"
readlink "/usr/local/greenplum-db" | grep "greenplum-db-${GPDB_VERSION}"

# Test $GPHOME is set
# shellcheck disable=SC1091
source /usr/local/greenplum-db/greenplum_path.sh
echo "$GPHOME" | grep /usr/local/greenplum-db

# Test binaries that are packaged runnable
# TODO: should test that package version matches binary version
# but first need to refactor packaging code
postgres --gp-version

# Test gpdb deb package can uninstall
# shellcheck disable=SC2035
apt-get remove --yes "$(dpkg-deb --field *.deb Package)"

# Test /usr/local/greenplum-db is removed after gpdb package is removed
if [ -d "/usr/local/greenplum-db" ]; then
	echo "/usr/local/greenplum-db should not exit after remove package"
	exit 1
fi

popd
