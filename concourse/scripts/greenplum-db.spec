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
Requires: libedit
Requires: libevent
Requires: libxml2
Requires: libyaml
Requires: zlib
Requires: openldap
Requires: openssh
Requires: openssl
Requires: perl
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
%{bin_gpdb}

%clean
rm -rf %{buildroot}

%post
# handle properly if /usr/local/greenplum-db already exists
ln -sT $RPM_INSTALL_PREFIX/%{name}-%{gpdb_version} $RPM_INSTALL_PREFIX/%{name} || true
# Update greenplum_path.sh for ${bin_gpdb}
sed -i -e "1 s~^\(GPHOME=\).*~\1$RPM_INSTALL_PREFIX/%{name}-%{gpdb_version}~" $RPM_INSTALL_PREFIX/%{name}-%{gpdb_version}/greenplum_path.sh

%postun
if [[ $(readlink $RPM_INSTALL_PREFIX/%{name}) == $RPM_INSTALL_PREFIX/%{name}-%{gpdb_version} ]]; then
  unlink $RPM_INSTALL_PREFIX/%{name}
fi
