#!/usr/bin/env bash
# Copyright (C) 2019-Present VMware, and affiliates Inc. All rights reserved.
# This program and the accompanying materials are made available under the
# terms of the under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain a
# copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

set -euox pipefail

generate_build_number() {
	pushd gpdb_src
	#Only if its git repro, add commit SHA as build number
	# BUILD_NUMBER file is used by getversion file in GPDB to append to version
	if [ -d .git ]; then
		echo "commit:$(git rev-parse HEAD)" >BUILD_NUMBER
	fi
	popd
}

install_python() {
	echo "Installing python"
	# shellcheck disable=SC2155
	export PYTHONHOME=$(find /opt -maxdepth 1 -type d -name "python-2*")
	export PATH="${PYTHONHOME}/bin:${PATH}"
	echo "${PYTHONHOME}/lib" >>/etc/ld.so.conf.d/gpdb.conf
	ldconfig
	export PYTHONHOME39=$(find /opt -maxdepth 1 -type d -name "python-3.9.*")
	if [ -n "${PYTHONHOME39}" ]; then
		export PATH="${PYTHONHOME39}/bin:${PATH}"
	fi
}

build_gpdb() {
	local greenplum_install_dir="${1}"

	pushd gpdb_src
	CC="gcc" CFLAGS="-O3 -fargument-noalias-global -fno-omit-frame-pointer -g" \
		./configure \
		--disable-debug-extensions \
		--disable-tap-tests \
		--enable-orca \
		--with-zstd \
		--with-gssapi \
		--with-libxml \
		--with-perl \
		--with-python \
		--with-openssl \
		--with-pam \
		--with-ldap \
		--with-pythonsrc-ext \
		--with-extra-version=" Open Source" \
		--prefix="${greenplum_install_dir}" \
		--mandir="${greenplum_install_dir}/man"
	make -j"$(nproc)"
	make install
	popd

	mkdir -p "${greenplum_install_dir}/etc"
	mkdir -p "${greenplum_install_dir}/include"
}

git_info() {
	local greenplum_install_dir="${1}"
	pushd gpdb_src
	./concourse/scripts/git_info.bash | tee "${greenplum_install_dir}/etc/git-info.json"
	popd
}

get_gpdb_tag() {
	pushd gpdb_src
	GPDB_VERSION=$(./concourse/scripts/git_info.bash | jq '.root.version' | tr -d '"')
	export GPDB_VERSION
	popd
}

include_dependencies() {
	local greenplum_install_dir="${1}"

	mkdir -p "${greenplum_install_dir}"/{lib,include,ext/python}

	declare -a library_search_path header_search_path vendored_headers vendored_libs pkgconfigs

	header_search_path=(/usr/local/include/ /usr/include/)
	vendored_headers=(zstd*.h)
	pkgconfigs=(libzstd.pc)

	vendored_libs=(libzstd.so{,.1,.1.3.7} libxerces-c{,-3.1}.so)

	if [[ -d /opt/gcc-6.4.0 ]]; then
		vendored_libs+=(libstdc++.so.6{,.0.22,*.pyc,*.pyo})
		library_search_path+=(/opt/gcc-6.4.0/lib64)
	fi
	#shellcheck disable=SC2207
	library_search_path+=($(cat /etc/ld.so.conf.d/*.conf | grep -v '#'))
	library_search_path+=(/lib64 /usr/lib64 /lib /usr/lib)

	# Vendor shared libraries - follow symlinks
	for path in "${library_search_path[@]}"; do if [[ -d "${path}" ]]; then for lib in "${vendored_libs[@]}"; do find -L "$path" -name "$lib" -exec cp -avn '{}' "${greenplum_install_dir}/lib" \;; done; fi; done
	# Vendor headers - follow symlinks
	for path in "${header_search_path[@]}"; do if [[ -d "${path}" ]]; then for header in "${vendored_headers[@]}"; do find -L "$path" -name "$header" -exec cp -avn '{}' "${greenplum_install_dir}/include" \;; done; fi; done
	# vendor pkgconfig files
	for path in "${library_search_path[@]}"; do if [[ -d "${path}/pkgconfig" ]]; then for pkg in "${pkgconfigs[@]}"; do find -L "$path"/pkgconfig/ -name "$pkg" -exec cp -avn '{}' "${greenplum_install_dir}/lib/pkgconfig" \;; done; fi; done

	echo "Copying python from ${PYTHONHOME} into ${greenplum_install_dir}/ext/python..."
	cp --archive "${PYTHONHOME}"/* "${greenplum_install_dir}/ext/python"

	# because we vendor python module, hence we need to re-generate the greenplum_path.sh with
	# additional PYTHONHOME information
	gpdb_src/gpMgmt/bin/generate-greenplum-path.sh yes >"${greenplum_install_dir}/greenplum_path.sh"
}

export_gpdb() {
	local greenplum_install_dir="${1}"
	local tarball="${2}"

	pushd "${greenplum_install_dir}"
	# Remove python bytecode
	find . -type f \( -iname \*.pyc -o -iname \*.pyo \) -delete
	tar -czf "${tarball}" ./*
	popd
}

# make sure if we vendor python, then the PYTHONHOME should point to it
check_pythonhome() {
	local greenplum_install_dir="${1}"
	local return_code

	pushd "${greenplum_install_dir}"
	return_code=$(
		# shellcheck disable=SC1091
		source greenplum_path.sh
		if [ -f "${greenplum_install_dir}/ext/python/bin/python" ]; then
			if [ "${PYTHONHOME}" = "${greenplum_install_dir}/ext/python" ]; then
				echo 0
			fi
		else
			if [ "${PYTHONHOME}" = "" ]; then
				echo 0
			fi
		fi
	)
	popd
	return_code="${return_code:-1}"
	return "${return_code}"
}

_main() {
	get_gpdb_tag
	PREFIX=${PREFIX:="/usr/local"}
	output_artifact_dir="${PWD}/gpdb_artifacts"
	if [[ ! -d "${output_artifact_dir}" ]]; then
		mkdir "${output_artifact_dir}"
	fi

	generate_build_number

	local greenplum_install_dir="${PREFIX}/greenplum-db-${GPDB_VERSION}"

	install_python
	build_gpdb "${greenplum_install_dir}"
	git_info "${greenplum_install_dir}"

	include_dependencies "${greenplum_install_dir}"
	check_pythonhome "${greenplum_install_dir}"

	export_gpdb "${greenplum_install_dir}" "${output_artifact_dir}/bin_gpdb.tar.gz"
}

_main "${@}"
