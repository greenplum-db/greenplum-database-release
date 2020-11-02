#!/usr/bin/env bash

push() {
	set -ex

	cd gpdb_src
	GPDB_VERSION=$(./getversion --short)

	cd ../tanzunet_client/
	make depend
	make build
	./bin/tanzunet-client upload --verbose --metadata "../greenplum-database-release/${TANZUNET_METADATA_FILE}" --search-path ../ --gpdb-version "${GPDB_VERSION}" --debug
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
	push "$@"
fi
