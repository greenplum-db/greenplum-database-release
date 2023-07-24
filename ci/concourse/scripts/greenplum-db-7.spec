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

%define _build_id_links none
%{!?gpdb_major_version:%global gpdb_major_version 7}

# Disable automatic dependency processing both for requirements and provides
AutoReqProv: no

%if "%{gpdb_oss}" == "true"
Name: open-source-greenplum-db-7
Conflicts: greenplum-db-7
%else
Name: greenplum-db-7
Conflicts: open-source-greenplum-db-7 <= %{rpm_gpdb_version}
%endif
Version: %{rpm_gpdb_version}
Release: %{gpdb_release}%{?dist}
Summary: Greenplum-DB
License: %{gpdb_license}
URL: %{gpdb_url}
Source0: gpdb.tar.gz
Prefix: /usr/local

%if 0%{?rhel}
Requires: apr apr-util
Requires: bash
Requires: bzip2
Requires: curl
Requires: iproute
Requires: krb5-devel
Requires: less
Requires: libcurl
Requires: libxml2
Requires: libyaml
Requires: openldap
Requires: openssh
Requires: openssh-clients
Requires: openssh-server
Requires: openssl
Requires: perl
Requires: python3
Requires: python39
Requires: readline
Requires: rsync
Requires: sed
Requires: tar
Requires: which
Requires: zip
Requires: zlib
Requires: llvm-libs
Requires: libuuid
%endif

%if "%{platform}" == "rhel8" || "%{platform}" == "rocky8" || "%{platform}" == "oel8"
Requires: libevent
Requires: libuv
Requires: libzstd
Requires: libcgroup-tools
%endif
%if "%{platform}" == "rhel7"
Requires: openssl-libs
Requires: libevent
Requires: libcgroup-tools
%endif
%if "%{platform}" == "rhel6"
Requires: libevent2
Requires: libcgroup
%endif

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
/usr/bin/env python3 -m compileall -q -x test .
popd

# Disable build root policy trying to generate %.pyo/%.pyc
exit 0

%files
# only Open Source Greenplum provide copyright, and the difference is the gpdb_name
# for open source greenplum it is greenplum-db, while non open source greenplum is greenplum-db
%if "%{gpdb_oss}" == "true"
%doc open_source_license_greenplum_database.txt
%endif
%{prefix}/greenplum-db-%{gpdb_version}
%config(noreplace) %{prefix}/greenplum-db-%{gpdb_version}/greenplum_path.sh

%post
if [ ! -e "${RPM_INSTALL_PREFIX}/greenplum-db" ];then
  ln -fsT "${RPM_INSTALL_PREFIX}/greenplum-db-%{gpdb_version}" "${RPM_INSTALL_PREFIX}/greenplum-db" || :
elif [ -L "${RPM_INSTALL_PREFIX}/greenplum-db" ] && [ -e "${RPM_INSTALL_PREFIX}/greenplum-db/bin/postgres" ] && [ -e "${RPM_INSTALL_PREFIX}/greenplum-db/greenplum_path.sh" ] ; then
  # Get the gpdb version from user's environment e.g. 7.0.0
  original_version=$(source ${RPM_INSTALL_PREFIX}/greenplum-db/greenplum_path.sh; ${RPM_INSTALL_PREFIX}/greenplum-db/bin/postgres --gp-version | grep -Eo "[0-9]\.[0-9]+\.[0-9]+")
  # Get the gpdb major version from user's environment e.g. 7
  original_major_version=${original_version:0:1}
  if [ ${original_major_version} == %{gpdb_major_version} ];then
    ln -fsT "${RPM_INSTALL_PREFIX}/greenplum-db-%{gpdb_version}" "${RPM_INSTALL_PREFIX}/greenplum-db" || :
  else
    echo "The expected symlink was not created because a file exists at that location symlinked to a different installed Greenplum Major version"
  fi
else
  echo "the expected symlink was not created because a file exists at that location"
fi

%postun
if [ $1 -eq 0 ] ; then
  if [ "$(readlink -f "${RPM_INSTALL_PREFIX}/greenplum-db")" == "${RPM_INSTALL_PREFIX}/greenplum-db-%{gpdb_version}" ]; then
    unlink "${RPM_INSTALL_PREFIX}/greenplum-db" || :
  fi
fi
