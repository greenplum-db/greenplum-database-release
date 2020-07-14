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
import os
from unittest import TestCase
from unittest.mock import Mock, patch, PropertyMock, call

from oss.rpmbuild import RPMPackageBuilder


class TestRPMPackageBuilder(TestCase):
    def setUp(self):
        os.system("rm -rf /tmp/lic.txt; echo 'license content' > /tmp/lic.txt")
        os.system("mkdir -p /tmp/gpdb_src")
        self.rpm_package_builder = RPMPackageBuilder(
            name="greenplum-db",
            release="1",
            platform="rhel6",
            summary="Greenplum-DB",
            license="Pivotal Software EULA",
            url="https://github.com/greenplum-db/gpdb",
            buildarch="x86_64",
            description="Greenplum Database",
            prefix="/usr/local",
            oss="true",
            bin_gpdb_path="bin_gpdb/bin_gpdb.tar.gz",
            spec_file_path="greenplum-database-release/ci/concourse/scripts/greenplum-db.spec",
            license_file_path="/tmp/lic.txt",
            gpdb_src_path="/tmp/gpdb_src"
        )

    @patch('oss.base.BasePackageBuilder.gpdb_version_short', new_callable=PropertyMock)
    def test_build_package_builder_settings(self, mock):
        mock.return_value = "gpdb-6.0.0-beta.5+dev.18.g6a02f28"
        self.assertEqual(self.rpm_package_builder.rpm_build_dir, "/root/rpmbuild")
        self.assertEqual(self.rpm_package_builder.rpm_gpdb_version, "gpdb_6.0.0_beta.5+dev.18.g6a02f28")
        self.assertEqual(self.rpm_package_builder.platform, "rhel6")
        self.assertEqual(self.rpm_package_builder.rpm_package_name, "greenplum-db-gpdb_6.0.0_beta.5+dev.18.g6a02f28-rhel6-x86_64.rpm")
        with self.assertRaisesRegex(Exception, 'The platform only support rhel6, rhel7'):
            self.rpm_package_builder.platform = "ubuntu18.04"
        self.assertEqual(self.rpm_package_builder.rpm_package_name,
                         "greenplum-db-gpdb-6.0.0-beta.5+dev.18.g6a02f28-rhel6-x86_64.rpm")

    @patch('oss.base.BasePackageBuilder.gpdb_version_short', new_callable=PropertyMock)
    @patch('oss.rpmbuild.RPMPackageBuilder._prepare_rpm_build_dir')
    @patch('oss.utils.Util.run_or_fail')
    def test_build_flags(self, run_or_fail_mock, prepare_rpm_build_dir_mock, gpdb_version_short_mock):
        gpdb_version_short_mock.return_value = "gpdb-6.0.0-beta.5+dev.18.g6a02f28"
        self.rpm_package_builder.build()
        self.assertEqual(
            run_or_fail_mock.call_args_list,
            [call(['/bin/bash', '-c',
                   'rpmbuild -bb /root/rpmbuild/SPECS/greenplum-db.spec '
                   '--define="rpm_gpdb_version gpdb_6.0.0_beta.5+dev.18.g6a02f28" '
                   '--define="gpdb_version gpdb-6.0.0-beta.5+dev.18.g6a02f28" '
                   '--define="gpdb_release 1" '
                   '--define="gpdb_name greenplum-db" '
                   '--define="gpdb_summary Greenplum-DB" '
                   '--define="gpdb_license Pivotal Software EULA" '
                   '--define="gpdb_url https://github.com/greenplum-db/gpdb" '
                   '--define="gpdb_buildarch x86_64" '
                   '--define="gpdb_description Greenplum Database" '
                   '--define="gpdb_prefix /usr/local" '
                   '--define="gpdb_oss true"'],
                  cwd='/root/rpmbuild')]
        )
