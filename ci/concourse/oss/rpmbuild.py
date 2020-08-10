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
import shutil
import tarfile
import tempfile
from contextlib import closing

from oss.base import BasePackageBuilder
from oss.utils import Util

NOTICE_FILE_CONTENT = '''Greenplum Database

Copyright (c) 2019 VMware, and affiliates Inc. All Rights Reserved.

This product is licensed to you under the Apache License, Version 2.0 (the "License").
You may not use this product except in compliance with the License.

This product may include a number of subcomponents with separate copyright notices
and license terms. Your use of these subcomponents is subject to the terms and
conditions of the subcomponent's license, as noted in the LICENSE file.

'''


class RPMPackageBuilder(BasePackageBuilder):
    # oss: if build the Open Source gpdb, this value should be 'true', it's string type not bool
    def __init__(self, name, release, platform, license, url, oss,
                 bin_gpdb_path, spec_file_path, license_file_path, gpdb_src_path):
        super(RPMPackageBuilder, self).__init__(bin_gpdb_path)

        self.name = name
        self.release = release
        self.license = license
        self.url = url
        self.oss = oss.lower()
        self.is_oss = oss.lower() == 'true'
        self.bin_gpdb_path = bin_gpdb_path
        self.spec_file_path = spec_file_path
        self.platform = platform
        self.license_file_path = license_file_path
        self.gpdb_src_path = gpdb_src_path

        self._pre_check()

    def _pre_check(self):
        if self.is_oss and not os.path.exists(self.gpdb_src_path):
            raise Exception("Building the Open-Source GPDB RPM installer need the gpdb_src repo!")

    def build(self):
        self._prepare_rpm_build_dir()

        build_flags = self._build_rpm_build_flags()
        spec_file_path = os.path.join(self.rpm_build_dir, "SPECS",  self.name + ".spec")

        command_str = "rpmbuild -bb %s %s" % (spec_file_path, build_flags)
        cmd = ['/bin/bash', '-c', command_str]
        Util.run_or_fail(cmd, cwd=self.rpm_build_dir)

    @property
    def rpm_build_dir(self):
        # Should return absolute path
        return "/root/rpmbuild"

    @property
    def rpm_gpdb_version(self):
        return self.gpdb_version_short.replace('-', '_')

    @property
    def platform(self):
        return self._platform

    @platform.setter
    def platform(self, value):
        if value not in ['rhel6', 'rhel7']:
            raise Exception("The platform only support rhel6, rhel7")
        self._platform = value

    @property
    def rpm_package_name(self):
        return "greenplum-db-%s-%s-x86_64.rpm" % (self.gpdb_version_short, self.platform)

    def _prepare_rpm_build_dir(self):
        for sub_dir in ["SOURCES", "SPECS"]:
            os.makedirs(os.path.join(self.rpm_build_dir, sub_dir), mode=0o755)

        temp_dir = tempfile.mkdtemp()
        print("TEMP DIR: %s" % temp_dir)

        print("Backup the bin_gpdb to %s/bin_gpdb_bak.tar.gz" % temp_dir)
        shutil.copy(self.bin_gpdb_path, os.path.join(temp_dir, "bin_gpdb_bak.tar.gz"))

        dest = os.path.join(temp_dir, 'bin_gpdb')
        print("Extracting the bin_gpdb.tar.gz to %s" % dest)
        with closing(tarfile.open(self.bin_gpdb_path)) as tar:
            tar.extractall(dest)

        osl_file_name = "open_source_license_greenplum_database.txt" if self.is_oss else "open_source_licenses.txt"

        print("Copy the OSL license file to the %s/bin_gpdb/%s" % (temp_dir, osl_file_name))
        shutil.copy(self.license_file_path,
                    os.path.join(temp_dir, "bin_gpdb/", osl_file_name))

        if self.is_oss:
            print("Copy the license file to the %s/bin_gpdb/LICENSE" % temp_dir)
            shutil.copy(os.path.join(self.gpdb_src_path, "LICENSE"), os.path.join(temp_dir, "bin_gpdb/LICENSE"))

            print("Copy the COPYRIGHT file to the %s/bin_gpdb/COPYRIGHT" % temp_dir)
            shutil.copy(os.path.join(self.gpdb_src_path, "COPYRIGHT"), os.path.join(temp_dir, "bin_gpdb/COPYRIGHT"))

            notice_file_path = "%s/bin_gpdb/NOTICE" % temp_dir
            print("Generate the NOTICE file to the %s" % notice_file_path)
            with open(notice_file_path, 'w') as notice_file:
                notice_file.write(NOTICE_FILE_CONTENT)
        else:
            # TODO: Pivotal EUAL file should be here!
            print("Pivotal EUAL file is here!")

        print("Packaging the bin_gpdb to bin_gpdb.tar.gz")
        # These code can not work on python2.6
        # For example on python2.7/3, the key prefix is './', eg. ./bin/initdb
        # But on the python2.6, the key doesn't include './', eg. bin/initdb
        # with closing(tarfile.open(self.bin_gpdb_path, 'w:gz')) as tar:
        #     tar.add(dest, arcname="./")

        # It's difficult to deal with python compatibility
        os.system("tar cvzf %s -C %s ." % (self.bin_gpdb_path, dest))

        shutil.copy(self.bin_gpdb_path, os.path.join(self.rpm_build_dir, "SOURCES/gpdb.tar.gz"))
        shutil.copy(self.spec_file_path, os.path.join(self.rpm_build_dir, "SPECS", self.name + ".spec"))

    def _build_rpm_build_flags(self):
        flags = [
            r'--define="rpm_gpdb_version %s"' % self.rpm_gpdb_version,
            r'--define="gpdb_version %s"' % self.gpdb_version_short,
            r'--define="gpdb_release %s"' % self.release
        ]

        possible_flags = ["LICENSE", "URL", "OSS"]

        for flag in possible_flags:
            value = getattr(self, flag.lower(), None)
            if not value:
                continue
            flags.append(r'--define="gpdb_%s %s"' % (flag.lower(), value))

        return " ".join(flags)
