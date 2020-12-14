#!/bin/bash
set -exo pipefail

# Locate correct gpdb version sha
if [ -d bin_gpdb ]; then
	mkdir -p /usr/local/greenplum-db-devel
	tar xzf bin_gpdb/*.tar.gz -C /usr/local/greenplum-db-devel
elif [ -d rpm_gpdb ]; then
	rpm -ivh rpm_gpdb/*.rpm
elif [ -d deb_gpdb ]; then
	dpkg -i deb_gpdb/*.deb
fi

pushd /usr/local/greenplum-db-*/include
VERSION_LINE=$(grep "GP_VERSION" pg_config.h | grep "commit")
GPDB_COMMIT=""
if [[ "$VERSION_LINE" =~ .*commit:(.*)\" ]]; then
	GPDB_COMMIT=${BASH_REMATCH[1]}
else
	echo "can't extract gpdb commit sha"
	exit 1
fi
if [ "$GPDB_COMMIT" ]; then
	echo "GPDB_COMMIT sha is $GPDB_COMMIT"
else
	echo "empty gpdb commit sha"
	exit 1
fi
popd

# Fetch gpdb source code for ICW testing
# TODO: make retrieve-gpdb6-src.yml take gpdb_src as input and output gpdb_src_fetched
git clone --depth 200 --branch 6X_STABLE \
	https://github.com/greenplum-db/gpdb.git gpdb_src
cd gpdb_src
git reset --hard "$GPDB_COMMIT"
