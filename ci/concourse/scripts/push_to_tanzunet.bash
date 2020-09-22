#!/usr/bin/env bash

push() {
	set -ex

	cd gpdb_src
	GPDB_VERSION=$(./getversion --short)

	cd ../pivnet_client/
	bundle install
	bundle exec pivnet_client upload --trace --verbose --metadata "../greenplum-database-release/${PIVNET_METADATA_FILE}" --search-path ../ --gpdb-version "${GPDB_VERSION}"
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
	push "$@"
fi
