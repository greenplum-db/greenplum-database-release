#!/usr/bin/env bash

push() {
	set -ex

	cd gpdb_src
	GPDB_VERSION=$(./getversion --short)

	chmod a+x ../tanzunet_client/gp-tanzunet-client
	../tanzunet_client/gp-tanzunet-client upload --verbose --parent-tanzunet-slug pivotal-gpdb --metadata "../greenplum-database-release/${TANZUNET_METADATA_FILE}" --search-path ../ --gpdb-version "${GPDB_VERSION}" --debug
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
	push "$@"
fi
