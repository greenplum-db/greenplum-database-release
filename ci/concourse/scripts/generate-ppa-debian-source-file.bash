#!/bin/bash

set -euo pipefail

DEBIAN_RELEASE_DIR="greenplum-database-release"
GPDB_SRC_DIR="gpdb"
GPDB_VERSION_SHORT=$(${GPDB_SRC_DIR}/getversion --short)

gpg --import <(echo "$GPG_PRIVATE_KEY")

set -x

# depends on debmake and other tools being available already in image

# Regex to capture required gporca version and download gporca source
ORCA_TAG=$(grep -Po 'v\d+.\d+.\d+' ${GPDB_SRC_DIR}/depends/conanfile_orca.txt)
git clone --branch "${ORCA_TAG}" https://github.com/greenplum-db/gporca.git ${GPDB_SRC_DIR}/gporca

cp -a ${DEBIAN_RELEASE_DIR}/greenplum-db-5/debian ${GPDB_SRC_DIR}/

# Create a changelog
pushd ${GPDB_SRC_DIR}
git rev-parse --short HEAD >BUILD_NUMBER
dch --create --package greenplum-db-5 -v "${GPDB_VERSION_SHORT}" "${RELEASE_MESSAGE}"
dch -r "ignored message"
popd

tar czf greenplum-db-5_"${GPDB_VERSION_SHORT}".orig.tar.gz ${GPDB_SRC_DIR}

# Generate source.changes file
pushd ${GPDB_SRC_DIR}
debuild -S -sa
popd

mv greenplum-db-5_"${GPDB_VERSION_SHORT}"* debian_source_files/
