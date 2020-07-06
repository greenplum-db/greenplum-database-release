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
Name: %{gpdb_name}
Version: %{rpm_gpdb_version}
Release: %{gpdb_release}%{?dist}
Summary: %{gpdb_summary}
License: %{gpdb_license}
URL: %{gpdb_url}
BuildArch: %{gpdb_buildarch}
Source0: gpdb.tar.gz
Buildroot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Prefix: %{gpdb_prefix}

# Override the built rpm filename to use version string with "-"s
# For reference, the original _rpmfilename:
# %%{ARCH}/%%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm
%define _rpmfilename %%{ARCH}/%%{NAME}-%{gpdb_version}-%%{RELEASE}.%%{ARCH}.rpm

# Disable automatic dependency processing both for requirements and provides
AutoReqProv: no

Requires: apr apr-util
Requires: bash
Requires: bzip2
Requires: curl
# krb5-devel provides libgssapi_krb5.so
Requires: krb5-devel
Requires: libcurl
Requires: libevent
Requires: libxml2
Requires: libyaml
Requires: zlib
Requires: openldap
Requires: openssh
Requires: openssl
Requires: perl
Requires: readline
Requires: rsync
Requires: sed
Requires: tar
Requires: zip
Requires: net-tools
Requires: less
Requires: openssh-clients
Requires: which
Requires: iproute
Requires: openssh-server
%if 0%{?rhel} == 7
Requires: openssl-libs
%endif

%define bin_gpdb %{prefix}/%{name}-%{gpdb_version}

%description
%{gpdb_description}

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
rm -rf %{buildroot}
mkdir -p %{buildroot}%{bin_gpdb}
cp -R * %{buildroot}%{bin_gpdb}

# Disable build root policy trying to generate %.pyo/%.pyc
exit 0

%files
# only Open Source Greenplum provide copyright, and the difference is the gpdb_name
# for open source greenplum it is greenplum-db, while non open source greenplum is greenplum-db
%if "%{gpdb_oss}" == "true"
%doc open_source_license_greenplum_database.txt
%endif
%{bin_gpdb}

%clean
rm -rf %{buildroot}

%post
if [ ! -e "$RPM_INSTALL_PREFIX/%{name}" ] || [ -L "$RPM_INSTALL_PREFIX/%{name}" ];then
  # handle properly if /usr/local/greenplum-db already exists
  ln -sT $RPM_INSTALL_PREFIX/%{name}-%{gpdb_version} $RPM_INSTALL_PREFIX/%{name} || true
  # Update greenplum_path.sh for ${bin_gpdb}
  sed -i -e "1 s~^\(GPHOME=\).*~\1$RPM_INSTALL_PREFIX/%{name}-%{gpdb_version}~" $RPM_INSTALL_PREFIX/%{name}-%{gpdb_version}/greenplum_path.sh
else
  echo "the expected symlink was not created because a file exists at that location"
fi

%postun
if [[ $(readlink $RPM_INSTALL_PREFIX/%{name}) == $RPM_INSTALL_PREFIX/%{name}-%{gpdb_version} ]]; then
  unlink $RPM_INSTALL_PREFIX/%{name}
fi
