#!/usr/bin/env python3
# -*- coding: utf-8 -*-
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
import glob
import os
import shutil


from oss.ppa import SourcePackageBuilder, DebianPackageBuilder
from oss.utils import PackageTester

class BuildAndTestPPA:
    def build(self):
        if os.path.isfile("bin_gpdb/bin_gpdb.tar.gz"):
            tarball_path="bin_gpdb/bin_gpdb.tar.gz"
        else:
            tarball_path=glob.glob("bin_gpdb/server-*.tar.gz")[0]

        package_builder = SourcePackageBuilder(
            bin_gpdb_path=tarball_path,
            package_name='greenplum-db-6',
            gpdb_src_path="gpdb_src",
            license_dir_path="license_file"
        )

        source_package = package_builder.build()
        builder = DebianPackageBuilder(source_package=source_package)
        builder.build_debian()

        deb_file_path = os.path.abspath(glob.glob("./*.deb")[0])
        print("Copy the DEB package to the output resource")
        shutil.copy(deb_file_path, os.path.join("gpdb_deb_installer", "greenplum-db-6-ubuntu18.04-amd64.deb"))

        print("Build DEB package finished!")
        return source_package

if __name__ == '__main__':
    build_test = BuildAndTestPPA()
    build_test.build()

    