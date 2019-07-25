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
from unittest import TestCase
from unittest.mock import Mock, patch, PropertyMock

from oss.rpmbuild import RPMPackageBuilder


class TestRPMPackageBuilder(TestCase):
    def setUp(self):
        os.system("rm -rf /tmp/lic.txt; echo 'license content' > /tmp/lic.txt")
        self.rpm_package_builder = RPMPackageBuilder(
            name="greenplum-database",
            release="1",
            platform="rhel6",
            summary="Greenplum-DB",
            license="Pivotal Software EULA",
            url="https://github.com/greenplum-db/gpdb",
            buildarch="x86_64",
            description="Greenplum Database",
            prefix="/usr/local",
            bin_gpdb_path="bin_gpdb/bin_gpdb.tar.gz",
            spec_file_path="greenplum-database-release/concourse/scripts/greenplum-db.spec",
            license_file_path="/tmp/lic.txt"
        )

    @patch('oss.base.BasePackageBuilder.gpdb_version_short', new_callable=PropertyMock)
    def test_build(self, mock):
        mock.return_value = "gpdb-6.0.0-beta.5+dev.18.g6a02f28"
        self.assertEqual(self.rpm_package_builder.rpm_build_dir, "/root/rpmbuild")
        self.assertEqual(self.rpm_package_builder.rpm_gpdb_version, "gpdb_6.0.0_beta.5+dev.18.g6a02f28")
        self.assertEqual(self.rpm_package_builder.platform, "rhel6")
        with self.assertRaisesRegex(Exception, 'The platform only support rhel6, rhel7'):
            self.rpm_package_builder.platform = "ubuntu18.04"
        self.assertEqual(self.rpm_package_builder.rpm_package_name,
                         "greenplum-database-gpdb-6.0.0-beta.5+dev.18.g6a02f28-rhel6-x86_64.rpm")
