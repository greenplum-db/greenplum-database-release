#!/usr/bin/env bash

set -e

build_gpdb_clients_msi() {
	local bin_gpdb_clients="${1}"
	local output_dir="${2}"

	local version
	version="$(tar -xzf "${bin_gpdb_clients}" --to-stdout version)" || return $?

	local output_msi="${output_dir}/greenplum-db-clients-${version}-x86_64.msi"

	tar -xzf "${bin_gpdb_clients}" --to-stdout greenplum-clients-x86_64.msi >"${output_msi}" || return $?
}

if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
	export -f build_gpdb_clients_msi
else
	build_gpdb_clients_msi "${@}"
	exit $?
fi
