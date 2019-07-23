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
import re
import subprocess
import tarfile


class Util:
    @staticmethod
    def strip_margin(text):
        return re.sub(r'\n[ \t]*\|', '\n', text)

    @staticmethod
    def extract_gpdb_version(bin_gpdb_path):
        with tarfile.open(bin_gpdb_path) as bin_gpdb_tar:
            member = bin_gpdb_tar.getmember('./etc/git-info.json')
            with bin_gpdb_tar.extractfile(member) as fd:
                git_info = json.loads(fd.read())
        return git_info['root']['version']

    @staticmethod
    def run_or_fail(cmd, cwd="."):
        return_code = subprocess.call(cmd, cwd=cwd)
        if return_code != 0:
            full_cmd = ' '.join(cmd)
            raise SystemExit(f'Exit {return_code}: Command "{full_cmd}" failed.\n')
