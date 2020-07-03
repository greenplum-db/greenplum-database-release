#!/bin/bash

set -euo pipefail

gpg --import <(echo "${GPG_PRIVATE_KEY}")
GPDB_VERSION_SHORT="$(gpdb/getversion --short)"
GPDB_VERSION_LONG="$(gpdb/getversion)"
dput "${PPA_REPO}" debian_source_files/greenplum-db-5_"${GPDB_VERSION_SHORT}"_source.changes >/dev/null
echo "Finished Uploading"
echo "Greenplum short version: ${GPDB_VERSION_SHORT}"
echo "Greenplum long version:  ${GPDB_VERSION_LONG}"
