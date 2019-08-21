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
import argparse
import glob
import os

from oss.ppa import SourcePackageBuilder, DebianPackageBuilder, LaunchpadPublisher
from oss.utils import PackageTester


def str2bool(v):
    return v.lower() != 'false'


def main(args):
    source_package = SourcePackageBuilder(
        bin_gpdb_path=args.bin_gpdb,
        package_name='greenplum-db',
        release_message=args.release_message,
        gpdb_src_path=args.gpdb_src,
        license_file=args.license_file,
        prefix=args.prefix,
        is_oss=args.oss
    ).build()

    builder = DebianPackageBuilder(source_package=source_package)
    builder.build_binary()

    if args.oss:
        deb_file_path = os.path.abspath(glob.glob("./*.deb")[0])
        print("Verify DEB package...")
        packager_tester = PackageTester(deb_file_path)
        packager_tester.test_package()
        print("All check actions passed!")

    if args.publish:
        builder.build_source()
        ppa_repo = os.environ["PPA_REPO"]
        publisher = LaunchpadPublisher(ppa_repo, source_package)
        publisher.publish()


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bin-gpdb", help="path to bin_gpdb.tar.gz", default='bin_gpdb/bin_gpdb.tar.gz')
    parser.add_argument('--release-message', help='release message for CHANGELOG', default='missing message')
    parser.add_argument('--gpdb-src', help='path to gpdb source code', default='gpdb_src')
    parser.add_argument('--license-file', help='path to OSL file', default='')
    parser.add_argument('--publish', help='publish to PPA', action='store_true', default=False)
    parser.add_argument('--prefix', help='publish to PPA', default='/usr/local')
    parser.add_argument('--oss', help='build OSS Greenplum Database', type=str2bool, default='false')
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_args()
    main(args)
