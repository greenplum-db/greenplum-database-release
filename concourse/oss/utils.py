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
import json
import os
import re
import subprocess
import tarfile
# Support centos6 and centos7, due to the python version is 2.6 on centos6
from contextlib import closing


class Util:
    @staticmethod
    def strip_margin(text):
        return re.sub(r'\n[ \t]*\|', '\n', text)

    @staticmethod
    def extract_gpdb_version(bin_gpdb_path):
        with closing(tarfile.open(bin_gpdb_path)) as bin_gpdb_tar:
            member = bin_gpdb_tar.getmember('./etc/git-info.json')
            with closing(bin_gpdb_tar.extractfile(member)) as fd:
                git_info = json.loads(fd.read())
        return git_info['root']['version']

    @staticmethod
    def run_or_fail(cmd, cwd="."):
        return_code = subprocess.call(cmd, cwd=cwd)
        if return_code != 0:
            full_cmd = ' '.join(cmd)
            raise SystemExit('Exit %s: Command "%s" failed.\n' % (return_code, full_cmd))


class PackageTester(object):

    def __init__(self, package_path):
        """
        PackageTester only for testing the OSS gpdb installer
        :param package_path: rpm/deb package path
        """
        self.package_path = package_path
        self.package_ext = os.path.splitext(package_path)[1].lower()

    def test_package(self):
        if self.package_ext == ".rpm":
            self._test_rpm()
        elif self.package_ext == ".deb":
            self._test_deb()
        else:
            raise Exception("Not support the package format: %s", self.package_ext)

    def _test_rpm(self):
        # check_output: need python>= 2.7
        # output = subprocess.check_output(['rpm', '-qlp', self.package_path]).decode('utf-8')
        output = self._cmd_output("rpm -qlp %s" % self.package_path)

        expected_files = [
            "/usr/local/greenplum-db-.*/COPYRIGHT",
            "/usr/local/greenplum-db-.*/LICENSE",
            "/usr/local/greenplum-db-.*/NOTICE",
            "/usr/local/greenplum-db-.*/open_source_license_greenplum_database.txt"
        ]
        for f in expected_files:
            assert bool(re.findall(f, output)), "Not Found: %s" % f

    def _test_deb(self):
        # output = subprocess.check_output(["dpkg", '-c', self.package_path]).decode('utf-8')
        output = self._cmd_output("dpkg -c %s" % self.package_path)

        expected_files = [
            "/usr/share/doc/greenplum-db/COPYRIGHT",
            "/usr/share/doc/greenplum-db/LICENSE",
            "/usr/share/doc/greenplum-db/NOTICE",
            "/usr/share/doc/greenplum-db/open_source_license_greenplum_database.txt"
        ]

        for f in expected_files:
            assert output.index(f) > -1, "Not Found: %s" % f

    def _cmd_output(self, cmd):
        # These codes can run both python2.6 and python2.7
        p = subprocess.Popen(cmd, shell=True, stdout=subprocess.PIPE)
        return p.communicate()[0].decode('utf-8')
