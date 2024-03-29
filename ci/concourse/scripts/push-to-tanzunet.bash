#!/usr/bin/env bash

push() {
	set -ex

	GPDB_VERSION=$(cat pivotal-gpdb/version | cut -d "#" -f 1)

	chmod a+x ./tanzunet_client/gp-tanzunet-client
	if [ "${RUN_MODE}" != "prod" ]; then
		./tanzunet_client/gp-tanzunet-client upload --verbose --parent-tanzunet-slug vmware-greenplum --metadata "./greenplum-database-release/${TANZUNET_METADATA_FILE}" --search-path ./ --gpdb-version "${GPDB_VERSION}" --debug --dryrun
	else
		./tanzunet_client/gp-tanzunet-client upload --verbose --parent-tanzunet-slug vmware-greenplum --metadata "./greenplum-database-release/${TANZUNET_METADATA_FILE}" --search-path ./ --gpdb-version "${GPDB_VERSION}" --debug
	fi
}

if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
	push "$@"
fi
