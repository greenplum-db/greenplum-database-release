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
import shutil
import tarfile
import tempfile
from pathlib import Path
from unittest import TestCase
from unittest.mock import patch, call, PropertyMock, Mock

from oss.ppa import SourcePackageBuilder, SourcePackage, LaunchpadPublisher, DebianPackageBuilder
from oss.utils import Util


class TestDebianPackageBuilder(TestCase):
    def setUp(self):
        source_package_mock = Mock()
        source_package_mock.dir.return_value = "some-dir"
        self.debian_package_builder = DebianPackageBuilder(source_package_mock)

    @patch('oss.utils.Util.run_or_fail')
    def test_build_binary(self, mocked_run_or_fail):
        self.debian_package_builder.build_binary()
        mocked_run_or_fail.assert_called_with(['debuild', '--unsigned-changes',
                                               '--unsigned-source', '--build=binary'],
                                              cwd="some-dir")

    @patch('oss.utils.Util.run_or_fail')
    def test_build_source(self, mocked_run_or_fail):
        self.debian_package_builder.build_source()
        mocked_run_or_fail.assert_called_with(['debuild', '-S', '-sa'], cwd="some-dir")


class TestLaunchpadPublisher(TestCase):
    def setUp(self):
        source_package_mock = Mock()
        source_package_mock.changes.return_value = "some-changes"
        self.launchpad_publisher = LaunchpadPublisher("ppa-repo-mock", source_package_mock)

    @patch('oss.utils.Util.run_or_fail')
    def test_publish(self, mocked_run_or_fail):
        self.launchpad_publisher.publish()
        mocked_run_or_fail.assert_called_with(['dput', 'ppa-repo-mock', 'some-changes'])


class TestSourcePackage(TestCase):
    def setUp(self):
        self.source_package = SourcePackage('a', 'b', 'c')

    def test_changes(self):
        self.assertEqual(self.source_package.changes(), 'a_b-c_source.changes')

    def test_dir(self):
        self.assertEqual(self.source_package.dir(), 'a-b')


class TestSourcePackageBuilder(TestCase):
    @patch('oss.utils.Util.extract_gpdb_version')
    def setUp(self, mock_extract_gpdb_version):
        mock_extract_gpdb_version.return_value = 'short-version'
        self.source_package_builder = SourcePackageBuilder('path', 'name', 'message', "gpdb_src", "license_file")
        self.temp_dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.temp_dir)

    @patch('oss.utils.Util.extract_gpdb_version')
    def test_gpdb_version_short_when_none_extracts_gpdb_version_from_path(self, mock_extract_gpdb_version):
        self.source_package_builder._gpdb_version_short = None
        mock_extract_gpdb_version.return_value = 'fake-version'
        self.assertEqual(self.source_package_builder.gpdb_version_short, 'fake-version')
        mock_extract_gpdb_version.assert_called_with('path')

    def test_gpdb_version_short_is_returned_when_already_set(self):
        self.source_package_builder._gpdb_version_short = 'a-version'
        self.assertEqual(self.source_package_builder.gpdb_version_short, 'a-version')

    def test_control_contains_package_name(self):
        control = self.source_package_builder._control()
        self.assertIn('Source: name', control)
        self.assertIn('Package: name', control)

    def test_install_location(self):
        self.assertEqual(self.source_package_builder.install_location(), '/opt/name-short-version')

    def test_install_contains_correct_path(self):
        install = self.source_package_builder._install()
        self.assertEqual(install, 'bin_gpdb/* /opt/name-short-version\ndoc_files/* /usr/share/doc/greenplum-db/\n')

    @patch('oss.utils.Util.run_or_fail')
    def test_generate_changelog_runs_dch_command(self, mocked_run_or_fail):
        self.source_package_builder.generate_changelog()
        self.assertEqual(
            mocked_run_or_fail.call_args_list,
            [call(['dch', '--create', '--package', 'name', '--newversion',
                   'short~version-%s' % self.source_package_builder.debian_revision, 'message'],
                  cwd='name-short~version'),
             call(['dch', '--release', 'ignored message'], cwd='name-short~version')])

    @patch('oss.ppa.SourcePackageBuilder._generate_license_files')
    @patch('oss.ppa.SourcePackageBuilder.source_dir', new_callable=PropertyMock)
    def test_create_debian_dir(self, mock_source_dir, mock_generate_license_files):
        mock_source_dir.return_value = self.temp_dir

        self.source_package_builder.create_debian_dir()
        debian_dir = os.path.join(self.temp_dir, 'debian')
        self.assertTrue(os.path.isdir(debian_dir))
        self.assertTrue(os.path.isfile(os.path.join(debian_dir, 'compat')))
        self.assertTrue(os.path.isfile(os.path.join(debian_dir, 'rules')))
        self.assertTrue(os.path.isfile(os.path.join(debian_dir, 'control')))

    @patch('oss.ppa.SourcePackageBuilder.create_source')
    @patch('oss.ppa.SourcePackageBuilder.create_debian_dir')
    @patch('oss.ppa.SourcePackageBuilder.generate_changelog')
    def test_build(self, mock1, mock2, mock3):
        source_package_builder = self.source_package_builder
        source_package = source_package_builder.build()
        self.assertEqual(source_package.package_name, source_package_builder.package_name)
        self.assertEqual(source_package.version, source_package_builder.gpdb_upstream_version)
        self.assertEqual(source_package.debian_revision, source_package_builder.debian_revision)
        mock1.assert_called()
        mock2.assert_called()
        mock3.assert_called()

    @patch('oss.ppa.SourcePackageBuilder.install_location')
    @patch('oss.ppa.SourcePackageBuilder.source_dir', new_callable=PropertyMock)
    def test_replace_greenplum_path_replaces_GPHOME_with_the_install_location(self, mock_source_dir,
                                                                              mock_install_location):
        mock_source_dir.return_value = self.temp_dir
        os.mkdir(os.path.join(self.temp_dir, 'bin_gpdb'))
        mock_install_location.return_value = 'fake-install-location'
        greenplum_path_sh = os.path.join(self.temp_dir, 'bin_gpdb', 'greenplum_path.sh')
        with open(greenplum_path_sh, mode='w') as path_file:
            path_file.writelines([
                'OTHER=123\n',
                'GPHOME=should-be-replaced\n',
                'thing\n'
            ])

        self.source_package_builder.replace_greenplum_path()
        expected = [
            'OTHER=123\n',
            'GPHOME=fake-install-location\n',
            'thing\n'
        ]
        with open(greenplum_path_sh) as greenplum_path_file:
            greenplum_path_contents = greenplum_path_file.readlines()
            self.assertEqual(greenplum_path_contents, expected)

    @patch('oss.ppa.SourcePackageBuilder.replace_greenplum_path')
    @patch('oss.ppa.tarfile')
    @patch('oss.ppa.SourcePackageBuilder.source_dir', new_callable=PropertyMock)
    def test_create_source_it_creates_the_source_directory_when_it_does_not_exist(self, mock_source_dir, _1, _2):
        source_dir = os.path.join(self.temp_dir, 'my_src')
        mock_source_dir.return_value = source_dir
        self.assertFalse(os.path.exists(source_dir))
        self.source_package_builder.create_source()
        self.assertTrue(os.path.exists(source_dir))

    @patch('oss.ppa.SourcePackageBuilder.replace_greenplum_path')
    @patch('oss.ppa.tarfile')
    @patch('oss.ppa.SourcePackageBuilder.source_dir', new_callable=PropertyMock)
    def test_create_source_it_removes_the_source_directory_when_it_already_exists(self, mock_source_dir, _1, _2):
        mock_source_dir.return_value = self.temp_dir
        file_path = os.path.join(self.temp_dir, 'a.txt')
        Path(file_path).touch()
        self.assertTrue(os.path.exists(file_path))
        self.source_package_builder.create_source()
        self.assertFalse(os.path.exists(file_path))
        self.assertTrue(os.path.exists(self.temp_dir))

    @patch('oss.ppa.SourcePackageBuilder.replace_greenplum_path')
    @patch('oss.ppa.SourcePackageBuilder.source_dir', new_callable=PropertyMock)
    def test_create_source_extracts_bin_and_archives_it_to_basename_of_source_dir(self, mock_source_dir,
                                                                                  mock_replace_greenplum_path):
        os.chdir(self.temp_dir)
        source_dir = os.path.join(self.temp_dir, 'my_src')
        os.mkdir(source_dir)
        bin_gpdb_path = os.path.join(self.temp_dir, 'bin_gpdb.tar.gz')
        mock_source_dir.return_value = source_dir
        filenames = 'a b.txt CD'.split()
        files_path = os.path.join(self.temp_dir, 'bin', 'app')
        os.makedirs(files_path, exist_ok=True)
        for filename in filenames:
            filepath = os.path.join(files_path, filename)
            Path(filepath).touch()
        with tarfile.open(bin_gpdb_path, 'w:gz') as tar:
            tar.add('bin')
        shutil.move('bin', 'bin-original')
        self.source_package_builder.bin_gpdb_path = bin_gpdb_path

        self.source_package_builder.create_source()
        expected_contents_set = set(map(lambda filename: f'my_src/bin_gpdb/bin/app/{filename}', filenames))
        repackaged_contents_set = set()
        with tarfile.open(os.path.join(self.temp_dir, 'name_short~version.orig.tar.gz')) as tar:
            repackaged_contents_set.update(map(lambda tar_info: tar_info.name, tar.getmembers()))
        self.assertEqual(len(repackaged_contents_set.intersection(expected_contents_set)), 3)
        mock_replace_greenplum_path.assert_called()


class TestUtil(TestCase):
    def test_strip_margin_noop_on_empty_string(self):
        self.assertEqual(Util.strip_margin(''), '')

    def test_strip_margin_removes_tabs(self):
        self.assertEqual(Util.strip_margin("\n\t\t\t|"), "\n")

    def test_strip_margin_removes_multiline_tabs(self):
        self.assertEqual(Util.strip_margin(f'''A
               |B
               |C'''),
                         "A\nB\nC")

    @patch('oss.utils.subprocess')
    def test_run_or_fail_when_successful_works(self, subprocess_mock):
        subprocess_mock.call.return_value = 0
        Util.run_or_fail("test-cmd", "test-cwd")
        subprocess_mock.call.assert_called_with("test-cmd", cwd="test-cwd")

    @patch('oss.utils.subprocess')
    def test_run_or_fail_when_fails_raises_system_exit(self, subprocess_mock):
        subprocess_mock.call.return_value = 1
        with self.assertRaises(SystemExit) as cm:
            Util.run_or_fail(["a", "b", "c"], "2")

        self.assertEqual(cm.exception.code, 'Exit 1: Command "a b c" failed.\n')

    def test_extract_gpdb_version(self):
        temp_dir = tempfile.mkdtemp()
        os.chdir(temp_dir)
        bin_gpdb_path = 'bin_gpdb.tar.gz'
        git_info_path = 'git-info.json'
        with open(git_info_path, "w") as git_info:
            git_info.write('{"root":{"version":"a-real-sha"}}')
        with tarfile.open(bin_gpdb_path, "w:gz") as tar:
            tar.add(git_info_path, arcname="./etc/git-info.json")

        self.assertEqual(Util.extract_gpdb_version(bin_gpdb_path), "a-real-sha")
        shutil.rmtree(temp_dir)
