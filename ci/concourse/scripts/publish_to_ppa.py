#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Copyright (C) 2019-Present Pivotal Software, Inc. All rights reserved.
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

from oss.ppa import SourcePackageBuilder, DebianPackageBuilder, LaunchpadPublisher
from oss.utils import PackageTester

if __name__ == '__main__':
    package_builder = SourcePackageBuilder(
        bin_gpdb_path='bin_gpdb_ubuntu18.04/bin_gpdb.tar.gz',
        package_name='greenplum-db',
        release_message=os.environ["RELEASE_MESSAGE"],
        gpdb_src_path="gpdb_src",
        license_dir_path="license_file"
    )

    gpdb_ppa_version = f'{package_builder.gpdb_upstream_version}-{package_builder.debian_revision}'
    with open("ppa_release/version.txt", "w") as f:
        f.write(gpdb_ppa_version)

    source_package = package_builder.build()
    builder = DebianPackageBuilder(source_package=source_package)
    builder.build_binary()
    builder.build_source()

    deb_file_path = os.path.abspath(glob.glob("./*.deb")[0])
    print("Verify DEB package...")
    packager_tester = PackageTester(deb_file_path)
    packager_tester.test_package()
    print("All check actions passed!")

    ppa_repo = os.environ["PPA_REPO"]
    publisher = LaunchpadPublisher(ppa_repo, source_package)
    publisher.publish()
