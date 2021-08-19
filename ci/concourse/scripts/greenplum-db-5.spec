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

%{!?gpdb_major_version:%global gpdb_major_version 5}

# Disable automatic dependency processing both for requirements and provides
AutoReqProv: no

Name: greenplum-db-5
Version: %{rpm_gpdb_version}
Release: %{gpdb_release}%{?dist}
Summary: Greenplum-DB
Group: Applications/Databases
License: %{gpdb_license}
URL: %{gpdb_url}
Obsoletes: greenplum-db < 6.0.0
Source0: gpdb.tar.gz
Prefix: /usr/local

# in sles11, the buildroot macro is not defined, it is not a problem for sles12, centos6, centos7
Buildroot: %{_topdir}/BUILD/%{name}-%{version}-%{release}.%{_arch}

%description
Greenplum Database

%prep
# If the rpm_gpdb_version macro is not defined, it gets interpreted as a literal string
#  The multiple '%' is needed to escape the macro
if [ %{rpm_gpdb_version} = '%%{rpm_gpdb_version}' ] ; then
  echo "The macro (variable) rpm_gpdb_version must be supplied as rpmbuild ... --define='rpm_gpdb_version [VERSION]'"
  exit 1
fi
if [ %{gpdb_version} = '%%{gpdb_version}' ] ; then
  echo "The macro (variable) gpdb_version must be supplied as rpmbuild ... --define='gpdb_version [VERSION]'"
  exit 1
fi

%setup -q -c -n %{name}-%{gpdb_version}

%install
mkdir -p %{buildroot}/%{prefix}/greenplum-db-%{gpdb_version}
cp -R * %{buildroot}/%{prefix}/greenplum-db-%{gpdb_version}

pushd %{buildroot}/%{prefix}/greenplum-db-%{gpdb_version}
ext/python/bin/python -m compileall -q -x test .
popd
# Disable build root policy trying to generate %.pyo/%.pyc
exit 0

%files
%{prefix}/greenplum-db-%{gpdb_version}
%config(noreplace) %{prefix}/greenplum-db-%{gpdb_version}/greenplum_path.sh

# Normally we would do this in a %post scriptlet but the existing greenplum-db (5.x.x)
# unconditionally removes the symlink as part of its %postun scriptlet which is executed *after*
# the new package's %post scriptlet.
# Creating the link in %posttrans should be the last scriptlet executed.
%post
if [ ! -e "${RPM_INSTALL_PREFIX}/greenplum-db" ] || [ -L "${RPM_INSTALL_PREFIX}/greenplum-db" ];then
  ln -fsT "${RPM_INSTALL_PREFIX}/greenplum-db-%{gpdb_version}" "${RPM_INSTALL_PREFIX}/greenplum-db" || :
else
    echo "the expected symlink was not created because a file exists at that location"
fi

%postun
if [ "$(readlink -f "${RPM_INSTALL_PREFIX}/greenplum-db")" == "${RPM_INSTALL_PREFIX}/greenplum-db-%{gpdb_version}" ]; then
  unlink "${RPM_INSTALL_PREFIX}/greenplum-db" || :
fi
