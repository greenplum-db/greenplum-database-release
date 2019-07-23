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
import fileinput
import os
import shutil
import tarfile

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


class SourcePackageBuilder:
    def __init__(self, bin_gpdb_path='', package_name='', release_message=''):
        self.bin_gpdb_path = bin_gpdb_path
        self.package_name = package_name
        self.release_message = release_message
        self._gpdb_version_short = None
        self.debian_revision = 1

    def build(self):
        self.create_source()
        self.create_debian_dir()
        self.generate_changelog()

        return SourcePackage(
            package_name=self.package_name,
            version=self.gpdb_version_short,
            debian_revision=self.debian_revision)

    @property
    def gpdb_version_short(self):
        if self._gpdb_version_short is None:
            self._gpdb_version_short = Util.extract_gpdb_version(self.bin_gpdb_path)
        return self._gpdb_version_short

    @property
    def source_dir(self):
        return f'{self.package_name}-{self.gpdb_version_short}'

    def create_source(self):
        if os.path.exists(self.source_dir) and os.path.isdir(self.source_dir):
            shutil.rmtree(self.source_dir)
        os.mkdir(self.source_dir, 0o755)

        with tarfile.open(self.bin_gpdb_path) as tar:
            dest = os.path.join(self.source_dir, 'bin_gpdb')
            tar.extractall(dest)

        self.replace_greenplum_path()

        # using _ here is debian convention
        archive_name = f'{self.package_name}_{self.gpdb_version_short}.orig.tar.gz'
        with tarfile.open(archive_name, 'w:gz') as tar:
            tar.add(self.source_dir, arcname=os.path.basename(self.source_dir))

    def replace_greenplum_path(self):
        greenplum_path = os.path.join(self.source_dir, 'bin_gpdb', 'greenplum_path.sh')
        with fileinput.FileInput(greenplum_path, inplace=True) as file:
            for line in file:
                if line.startswith('GPHOME='):
                    print(f'GPHOME={self.install_location()}')
                else:
                    print(line, end='')

    def create_debian_dir(self):
        debian_dir = os.path.join(self.source_dir, 'debian')
        os.mkdir(debian_dir)

        with open(os.path.join(debian_dir, 'compat'), mode='x') as fd:
            fd.write('9\n')

        with open(os.path.join(debian_dir, 'copyright'), mode='x') as fd:
            fd.write(self._copyright())

        with open(os.path.join(debian_dir, 'rules'), mode='x') as fd:
            fd.write(self._rules())
        os.chmod(os.path.join(debian_dir, 'rules'), 0o755)

        with open(os.path.join(debian_dir, 'control'), mode='x', encoding='utf-8') as fd:
            fd.write(self._control())

        with open(os.path.join(debian_dir, 'install'), mode='x') as fd:
            fd.write(self._install())

    def generate_changelog(self):
        debian_revision = 1
        new_version = f'{self.gpdb_version_short}-{debian_revision}'
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
        return f'bin_gpdb/* {self.install_location()}\n'

    def install_location(self):
        return f'/opt/{self.package_name}-{self.gpdb_version_short}'

    def _copyright(self):
        return Util.strip_margin(
            '''Portions Copyright (c) 2005-2008, Greenplum inc
              |Portions Copyright (c) 2012-Present Pivotal Software, Inc.
              |''')

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
        return Util.strip_margin(
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
               |    libedit2,
               |    libevent-2.1-6,
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
