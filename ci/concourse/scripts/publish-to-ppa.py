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

from oss.ppa import LaunchpadPublisher
from buildppa import BuildAndTestPPA

if __name__ == '__main__':

    build_test = BuildAndTestPPA()
    source_package = build_test.build()

    ppa_repo = os.environ["PPA_REPO"]
    publisher = LaunchpadPublisher(ppa_repo, source_package)
    publisher.publish()
