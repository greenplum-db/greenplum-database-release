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
import fileinput
import glob
import os
import shutil
import tarfile

from oss.base import BasePackageBuilder
from oss.utils import Util


class DebianPackageBuilder:
    def __init__(self, source_package=None):
        self.source_package = source_package

    def build_binary(self):
        cmd = ['debuild', '--unsigned-changes', '--unsigned-source', '--build=binary']
        Util.run_or_fail(cmd, cwd=self.source_package.dir())

    def build_source(self):
        # -S should be equivalent to the long option `--build=source` but it is not
        # -sa forces the inclusion of the original source (no long-opt)
        cmd = ['debuild', '-S', '-sa']
        Util.run_or_fail(cmd, cwd=self.source_package.dir())

    def build_debian(self):
        cmd = ['dpkg-deb', '--build', self.source_package.dir()]
        Util.run_or_fail(cmd, cwd=".")

class LaunchpadPublisher:
    def __init__(self, ppa_repo, source_package):
        self.ppa_repo = ppa_repo
        self.source_package = source_package

    def publish(self):
        cmd = ['dput', self.ppa_repo, self.source_package.changes()]
        Util.run_or_fail(cmd)


class SourcePackage:
    def __init__(self, package_name=None, version=None, debian_revision=None):
        self.package_name = package_name
        self.version = version
        self.debian_revision = debian_revision

    def changes(self):
        return f'{self.package_name}_{self.version}-{self.debian_revision}_source.changes'

    def dir(self):
        return f'{self.package_name}-{self.version}'


class SourcePackageBuilder(BasePackageBuilder):
    def __init__(self, bin_gpdb_path='', package_name='', release_message='', gpdb_src_path="", license_dir_path="", ppa=False, clients=False):
        super(SourcePackageBuilder, self).__init__(bin_gpdb_path, clients)

        self.bin_gpdb_path = bin_gpdb_path
        self.package_name = package_name
        self.release_message = release_message
        self.debian_revision = 1
        self.gpdb_src_path = gpdb_src_path
        self.license_dir_path = license_dir_path
        # 6.0.0-beta.7 ==> 6.0.0~beta.7
        # ref: https://manpages.debian.org/wheezy/dpkg-dev/deb-version.5.en.html#Sorting_Algorithm
        self.gpdb_upstream_version = self.gpdb_version_short.replace("-", "~")
        self.gpdb_major_version = self.gpdb_version_short.split(".")[0]
        self.ppa = ppa
        self.clients = clients
        if "GPDB_BUILDARCH" in os.environ:
            self.build_arch=os.environ["GPDB_BUILDARCH"]
        if "GPDB_URL" in os.environ:
            self.gpdb_url=os.environ["GPDB_URL"]
        if "GPDB_DESCRIPTION" in os.environ:
            self.gpdb_description=os.environ["GPDB_DESCRIPTION"]
        if "GPDB_NAME" in os.environ:
            self.gpdb_name = os.environ["GPDB_NAME"]
        if "GPDB_PREFIX" in os.environ:
            self.gpdb_prefix = os.environ["GPDB_PREFIX"]
        if "GPDB_OSS" in os.environ and os.environ["GPDB_OSS"] == "true":
            self.gpdb_oss = True
        else:
            self.gpdb_oss = False

    def build(self):
        self.create_source()
        self.create_debian_dir()
        if self.ppa:
            self.generate_changelog()

        return SourcePackage(
            package_name=self.package_name,
            version=self.gpdb_upstream_version,
            debian_revision=self.debian_revision)

    @property
    def source_dir(self): 
        dir = f'{self.package_name}-{self.gpdb_upstream_version}'
        return dir

    def create_source(self):
        if os.path.exists(self.source_dir) and os.path.isdir(self.source_dir):
            shutil.rmtree(self.source_dir)
        os.mkdir(self.source_dir, 0o755)

        with tarfile.open(self.bin_gpdb_path) as tar:
            if self.ppa:
                dest = os.path.join(self.source_dir, 'bin_gpdb')
            else:
                dest = f'{self.package_name}-{self.gpdb_upstream_version}/{self.gpdb_prefix}/{self.gpdb_name}-{self.gpdb_version_short}'
                if os.path.exists(dest) and os.path.isdir(dest):
                    shutil.rmtree(dest)
                os.makedirs(dest, 0o755)
            tar.extractall(dest)
        if self.clients:
            self.replace_greenplum_path()
        # using _ here is debian convention
        archive_name = f'{self.package_name}_{self.gpdb_upstream_version}.orig.tar.gz'
        with tarfile.open(archive_name, 'w:gz') as tar:
            tar.add(self.source_dir, arcname=os.path.basename(self.source_dir))

    def create_debian_dir(self):
        if self.ppa:
            debian_dir = os.path.join(self.source_dir, 'debian')
        else:
            debian_dir = os.path.join(self.source_dir, 'DEBIAN')
        os.mkdir(debian_dir)
        if not self.ppa:
            doc_dir = f'{self.package_name}-{self.gpdb_upstream_version}/usr/share/doc/greenplum-db/'
        else:
            doc_dir = os.path.join(self.source_dir, "doc_files")
        os.makedirs(doc_dir, exist_ok=True)

        if self.ppa:
            with open(os.path.join(debian_dir, 'compat'), mode='x') as fd:
                fd.write('9\n')

        self._generate_license_files(doc_dir)

        with open(os.path.join(debian_dir, 'rules'), mode='x') as fd:
            fd.write(self._rules())
        os.chmod(os.path.join(debian_dir, 'rules'), 0o755)

        with open(os.path.join(debian_dir, 'control'), mode='x', encoding='utf-8') as fd:
            fd.write(self._control())

        with open(os.path.join(debian_dir, 'install'), mode='x') as fd:
            fd.write(self._install())

        with open(os.path.join(debian_dir, 'postinst'), mode='x') as fd:
            fd.write(self._postinst())
        os.chmod(os.path.join(debian_dir, 'postinst'), 0o775)

        with open(os.path.join(debian_dir, 'prerm'), mode='x') as fd:
            fd.write(self._prerm())
        os.chmod(os.path.join(debian_dir, 'prerm'), 0o775)

        if not self.ppa:
            with open(os.path.join(debian_dir, 'postrm'), mode='x') as fd:
                fd.write(self._postrm())
            os.chmod(os.path.join(debian_dir, 'postrm'), 0o775)

    def generate_changelog(self):
        new_version = f'{self.gpdb_upstream_version}-{self.debian_revision}'
        cmd = [
            'dch', '--create',
            '--package', self.package_name,
            '--newversion', new_version,
            self.release_message
        ]
        Util.run_or_fail(cmd, cwd=self.source_dir)

        cmd = ['dch', '--release', 'ignored message']
        Util.run_or_fail(cmd, cwd=self.source_dir)

    def _install(self):
        return f'bin_gpdb/* {self.install_location()}\ndoc_files/* /usr/share/doc/greenplum-db/\n'

    def install_location(self):
        if self.ppa:
            loc = f'/opt/greenplum-db-{self.gpdb_version_short}'
        else:
            loc = f'/usr/local/{self.gpdb_name}-{self.gpdb_version_short}'
        return loc

    def _generate_license_files(self, root_dir):
        if self.ppa or self.gpdb_oss:
            shutil.copy(os.path.join(self.gpdb_src_path, "LICENSE"),
                        os.path.join(root_dir, "LICENSE"))

            shutil.copy(os.path.join(self.gpdb_src_path, "COPYRIGHT"),
                        os.path.join(root_dir, "COPYRIGHT"))

        if not self.clients:
            license_file_path = os.path.abspath(glob.glob(os.path.join(self.license_dir_path, "*.txt"))[0])
            if self.ppa or self.gpdb_oss:
                shutil.copy(license_file_path, os.path.join(root_dir, "open_source_license_greenplum_database.txt"))
            else:
                shutil.copy(license_file_path, os.path.join(root_dir, "open_source_licenses.txt"))

        notice_content = '''Greenplum Database

Copyright (c) 2019 VMware, and affiliates Inc. All Rights Reserved.

This product is licensed to you under the Apache License, Version 2.0 (the "License").
You may not use this product except in compliance with the License.

This product may include a number of subcomponents with separate copyright notices
and license terms. Your use of these subcomponents is subject to the terms and
conditions of the subcomponent's license, as noted in the LICENSE file.
'''
        if self.ppa or self.gpdb_oss:
            with open(os.path.join(root_dir, "NOTICE"), 'w') as notice_file:
                notice_file.write(notice_content)

    def _rules(self):
        return Util.strip_margin(
            '''#!/usr/bin/make -f
              |
              |include /usr/share/dpkg/default.mk
              |
              |%:
              |	dh $@ --parallel
              |
              |# debian policy is to not use /usr/local
              |# dh_usrlocal does some funny stuff; override to do nothing
              |override_dh_usrlocal:
              |
              |# skip scanning for shlibdeps?
              |override_dh_shlibdeps:
              |
              |# skip removing debug output
              |override_dh_strip:
              |''')

    def _control(self):
        if self.ppa:
            control = Util.strip_margin(
                f'''Source: {self.package_name}
                |Maintainer: Pivotal Greenplum Release Engineering <gp-releng@pivotal.io>
                |Section: database
                |Build-Depends: debhelper (>= 9)
                |
                |Package: {self.package_name}
                |Architecture: amd64
                |Depends: libapr1,
                |    libaprutil1,
                |    bash,
                |    bzip2,
                |    krb5-multidev,
                |    libcurl3-gnutls,
                |    libcurl4,
                |    libevent-2.1-6,
                |    libreadline7,
                |    libxml2,
                |    libyaml-0-2,
                |    zlib1g,
                |    libldap-2.4-2,
                |    openssh-client,
                |    openssh-server,
                |    openssl,
                |    perl,
                |    rsync,
                |    sed,
                |    tar,
                |    zip,
                |    net-tools,
                |    less,
                |    iproute2
                |Description: Greenplum Database
                |  Greenplum Database is an advanced, fully featured, open source data platform.
                |  It provides powerful and rapid analytics on petabyte scale data volumes.
                |  Uniquely geared toward big data analytics, Greenplum Database is powered by
                |  the world's most advanced cost-based query optimizer delivering high
                |  analytical query performance on large data volumes.The Greenplum Database®
                |  project is released under the Apache 2 license.  We want to thank all our
                |  current community contributors and all who are interested in new
                |  contributions.  For the Greenplum Database community, no contribution is too
                |  small, we encourage all types of contributions.
                |''')
        elif self.clients:
            control = Util.strip_margin(
                f'''Package: greenplum-db-clients
                |Priority: extra
                |Maintainer: gp-releng@pivotal.io
                |Architecture: {self.build_arch}
                |Version: {self.gpdb_version_short}
                |Provides: Pivotal
                |Description: {self.gpdb_description}
                |Homepage: {self.gpdb_url}
                |Depends: libapr1,
                |   libaprutil1,
                |	libreadline7,
                |   bzip2,
                |   krb5-multidev,
                |   libcurl3-gnutls,
                |   libcurl4,
                |   libedit2,
                |   libevent-2.1-6,
                |   libxml2,
                |   libyaml-0-2,
                |   zlib1g,
                |   libldap-2.4-2,
                |   openssh-client,
                |   openssl,
                |   zip
                |''')
        else:
            control = Util.strip_margin(
                f'''Package: greenplum-db-{self.gpdb_major_version}
                |Priority: extra
                |Maintainer: gp-releng@pivotal.io
                |Architecture: {self.build_arch}
                |Version: {self.gpdb_version_short}
                |Provides: Pivotal
                |Description: {self.gpdb_description}
                |Homepage: {self.gpdb_url}
                |Depends: libapr1,
                |    libaprutil1,
                |    bash,
                |    bzip2,
                |    krb5-multidev,
                |    libcurl3-gnutls,
                |    libcurl4,
                |    libevent-2.1-6,
                |    libreadline7,
                |    libxml2,
                |    libyaml-0-2,
                |    zlib1g,
                |    libldap-2.4-2,
                |    openssh-client,
                |    openssh-server,
                |    openssl,
                |    perl,
                |    rsync,
                |    sed,
                |    tar,
                |    zip,
                |    net-tools,
                |    less,
                |    iproute2,
                |    iputils-ping,
                |    locales
                |''')
        return control
                
    def _postinst(self):
        if self.ppa:
            postinst = Util.strip_margin(
            f'''#!/usr/bin/env bash
            |cd {self.install_location()}
            |ext/python/bin/python -m compileall -q -x test .
            ''')
        else:
            postinst = Util.strip_margin(
            f'''#!/bin/sh
            |set -e
            |cd {self.gpdb_prefix}/
            |rm -f {self.gpdb_name}
            |ln -s {self.gpdb_prefix}/{self.gpdb_name}-{self.gpdb_version_short} {self.gpdb_name}
            |cd {self.gpdb_name}-{self.gpdb_version_short}
            |ext/python/bin/python -m compileall -q -x test .
            |exit 0
            ''')
        return postinst

    def _prerm(self):
        return Util.strip_margin(
            f'''#!/usr/bin/env bash
            |dpkg -L {self.package_name} | grep '\.py$' | while read file; do rm -f "${{file}}"[co] >/dev/null; done
            ''')
    
    def _postrm(self):
        return Util.strip_margin(
            f'''#!/bin/sh
            |set -e
            |rm -f {self.gpdb_prefix}/{self.gpdb_name}
            |exit 0
            ''')
    
    def replace_greenplum_path(self):
        dest = f'{self.package_name}-{self.gpdb_upstream_version}/{self.gpdb_prefix}/{self.gpdb_name}-{self.gpdb_version_short}'
        greenplum_path = os.path.join(dest, 'greenplum_clients_path.sh')
        with fileinput.FileInput(greenplum_path, inplace=True) as file:
            for line in file:
                if line.startswith('GPHOME_CLIENTS='):
                    print(f'GPHOME_CLIENTS={self.install_location()}')
                else:
                    print(line, end='')
