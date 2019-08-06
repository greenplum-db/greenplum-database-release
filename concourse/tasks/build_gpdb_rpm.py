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
import os
import glob
import shutil

from oss.rpmbuild import RPMPackageBuilder

if __name__ == '__main__':
    license_file_path = ""

    gpdb_name = os.environ["GPDB_NAME"]
    if os.path.exists("license_file"):
        license_file_path = os.path.abspath(glob.glob("license_file/*.txt")[0])

    rpm_builder = RPMPackageBuilder(
        name=gpdb_name,
        release=os.environ["GPDB_RELEASE"],
        platform=os.environ["PLATFORM"],
        summary=os.environ["GPDB_SUMMARY"],
        license=os.environ["GPDB_LICENSE"],
        url=os.environ["GPDB_URL"],
        buildarch=os.environ["GPDB_BUILDARCH"],
        description=os.environ["GPDB_DESCRIPTION"],
        prefix=os.environ["GPDB_PREFIX"],
        oss=os.getenv("GPDB_OSS", "false"),
        bin_gpdb_path="bin_gpdb/bin_gpdb.tar.gz",
        spec_file_path="greenplum-database-release/concourse/scripts/greenplum-db.spec",
        license_file_path=license_file_path
    )

    rpm_builder.build()

    # Copy the RPM package to output resource
    print("Copy the RPM package to the output resource")
    rpm_file_path = os.path.abspath(glob.glob("%s/RPMS/x86_64/*.rpm" % rpm_builder.rpm_build_dir)[0])
    shutil.copy(rpm_file_path, os.path.join("gpdb_rpm_installer", rpm_builder.rpm_package_name))
