#!/usr/bin/env bash
# Copyright (C) 2019-Present Pivotal Software, Inc. All rights reserved.
# This program and the accompanying materials are made available under the
# terms of the under the Apache License, Version 2.0 (the "License”); you may
# not use this file except in compliance with the License. You may obtain a
# copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

set -euox pipefail

fetch_orca_src () {
    local orca_tag="${1}"

    echo "Downloading greenplum-db/gporca@${orca_tag}"
    mkdir orca_src
    wget --quiet --output-document=- "https://github.com/greenplum-db/gporca/archive/${orca_tag}.tar.gz" \
        | tar xzf - --strip-components=1 --directory=orca_src
}

build_xerces () {
    echo "Building Xerces-C"
    mkdir -p xerces_patch/concourse
    cp -r orca_src/concourse/xerces-c xerces_patch/concourse
    cp -r orca_src/patches/ xerces_patch
    /usr/bin/python xerces_patch/concourse/xerces-c/build_xerces.py --output_dir="/usr/local"
    rm -rf build
}

build_orca () {
    echo "Building orca"
    orca_src/concourse/build_and_test.py --build_type=RelWithDebInfo --output_dir="/usr/local" --skiptests
    # FIXME: build_and_test.py prepends `..` to the output_dir so we have to copy in to /usr/local
    # ourselves
    cp -a usr/local/* /usr/local
    rm -rf usr build
    # RHEL does not include `/usr/local/lib` in the default search path
    echo "/usr/local/lib" >> /etc/ld.so.conf.d/gpdb.conf
    ldconfig
}

install_python () {
    echo "Installing python"
    tar xzf python-tarball/python-*.tar.gz -C /opt --strip-components=2
    export PATH="/opt/python-2.7.12/bin:${PATH}"
    export PYTHONHOME=/opt/python-2.7.12
    echo "/opt/python-2.7.12/lib" >> /etc/ld.so.conf.d/gpdb.conf
    ldconfig
}

generate_build_number() {
  pushd gpdb_src
    #Only if its git repro, add commit SHA as build number
    # BUILD_NUMBER file is used by getversion file in GPDB to append to version
    if [ -d .git ] ; then
      echo "commit:$(git rev-parse HEAD)" > BUILD_NUMBER
    fi
  popd
}

build_gpdb () {
    local greenplum_install_dir="${1}"

    pushd gpdb_src
        CC="gcc" CFLAGS="-O3 -fargument-noalias-global -fno-omit-frame-pointer -g" \
            ./configure \
                --enable-orca \
                --with-zstd \
                --with-gssapi \
                --with-libxml \
                --with-perl \
                --with-python \
                --with-openssl \
                --with-pam \
                --with-ldap \
                --prefix="${greenplum_install_dir}" \
                --mandir="${greenplum_install_dir}/man"
        make -j
        make install
    popd


    mkdir -p "${greenplum_install_dir}/etc"
    mkdir -p "${greenplum_install_dir}/include"
}

include_xerces () {
    local greenplum_install_dir="${1}"

    echo "Including libxerces-c in greenplum package"
    cp --archive /usr/local/lib/libxerces-c*.so "${greenplum_install_dir}/lib"
}

include_gporca () {
    local greenplum_install_dir="${1}"

    echo "Including libgpopt in greenplum package"
    cp --archive /usr/local/lib/libgpopt.so.* "${greenplum_install_dir}/lib"
}

include_python () {
    local greenplum_install_dir="${1}"

    mkdir -p "${greenplum_install_dir}/ext/python"
    echo "Copying python from /opt/python-2.7.12 into ${greenplum_install_dir}/ext/python..."
    cp --archive /opt/python-2.7.12/* "${greenplum_install_dir}/ext/python"
}

include_libstdcxx () {
    local greenplum_install_dir="${1}"

    # if this is a platform that uses a non-system toolchain, libstdc++ needs to be vendored
    if [ -d /opt/gcc-6.4.0 ]; then
        cp --archive /opt/gcc-6.4.0/lib64/libstdc++.so.6{,.0.22} "${greenplum_install_dir}/lib"
    fi
}

include_zstd () {
    local greenplum_install_dir="${1}"
    local platform
    platform="$(python -mplatform)"

    local libdir
    case "${platform}" in
    *centos*) libdir=/usr/lib64 ;;
    *Ubuntu*) libdir=/usr/lib ;;
    *) return ;;
    esac

    cp --archive ${libdir}/libzstd.so.1* "${greenplum_install_dir}/lib"
}

export_gpdb () {
    local greenplum_install_dir="${1}"
    local tarball="${2}"

    pushd "${greenplum_install_dir}"
      (source greenplum_path.sh; python -m compileall -q -x test .)
      tar -czf "${tarball}" ./*
    popd
}

_main () {
    export ORCA_TAG="$(grep 'ORCA_TAG:' gpdb_src/concourse/tasks/compile_gpdb.yml | cut -d ':' -f 2 | tr -d '[:space:]')"
    fetch_orca_src "${ORCA_TAG}"

    if [ -e /opt/gcc_env.sh ]; then
        . /opt/gcc_env.sh
    fi

    build_xerces
    build_orca

    install_python

    generate_build_number

    local greenplum_install_dir="/usr/local/greenplum-db-oss"
    build_gpdb "${greenplum_install_dir}"

    include_xerces "${greenplum_install_dir}"
    include_gporca "${greenplum_install_dir}"
    include_python "${greenplum_install_dir}"
    include_libstdcxx "${greenplum_install_dir}"
    include_zstd "${greenplum_install_dir}"
    export_gpdb "${greenplum_install_dir}" "${PWD}/gpdb_artifacts/bin_gpdb.tar.gz"

}

_main "${@}"
