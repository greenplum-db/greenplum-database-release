%{!?gpdb_clients_name: %define gpdb_clients_name greenplum-db-clients}
# %%{rpm_gpdb_clients_version} must be supplied or will exit in %%prep
# %%{gpdb_clients_version} must be supplied or will exit in %%prep
%{!?gpdb_clients_release: %define gpdb_clients_release 1}
%{!?gpdb_clients_summary: %define gpdb_clients_summary Greenplum-DB-Clients}
%{!?gpdb_clients_license: %define gpdb_clients_license Pivotal Beta EULA}
%{!?gpdb_clients_url: %define gpdb_clients_url https://network.tanzu.vmware.com/products/pivotal-gpdb/}
%{!?gpdb_clients_buildarch: %define gpdb_clients_buildarch x86_64}
%{!?gpdb_clients_description: %define gpdb_clients_description Greenplum Database Clients}
%{!?gpdb_clients_prefix: %define gpdb_clients_prefix /usr/local}


Name: %{gpdb_clients_name}
Version: %{rpm_gpdb_clients_version}
Release: %{gpdb_clients_release}%{?dist}
Summary: %{gpdb_clients_summary}
License: %{gpdb_clients_license}
URL: %{gpdb_clients_url}
BuildArch: %{gpdb_clients_buildarch}
Source0: gpdb_clients.tar.gz
Buildroot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Prefix: %{gpdb_clients_prefix}

# Override the built rpm filename to use version string with "-"s
# For reference, the original _rpmfilename:
# %%{ARCH}/%%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm
%define _rpmfilename %%{ARCH}/%%{NAME}-%{gpdb_clients_version}-%%{RELEASE}.%%{ARCH}.rpm

# Disable automatic dependency processing both for requirements and provides
AutoReqProv: no

%if 0%{?rhel}
Requires: apr
%else
Requires: libapr1
%endif
Requires: bzip2
Requires: libedit
%if 0%{?rhel}
Requires: libyaml
%else
Requires: libyaml-0-2
%endif
Requires: zlib
Requires: openssh
%if 0%{?rhel} == 6
Requires: libevent2
%else
Requires: libevent
%endif

%define bin_gpdb %{prefix}/%{name}-%{gpdb_clients_version}
%description
%{gpdb_clients_description}

%prep
# If the rpm_gpdb_clients_version macro is not defined, it gets interpreted as a literal string
#  The multiple '%' is needed to escape the macro
if [ %{rpm_gpdb_clients_version} = '%%{rpm_gpdb_clients_version}' ] ; then
  echo "The macro (variable) rpm_gpdb_clients_version must be supplied as rpmbuild ... --define='rpm_gpdb_clients_version [VERSION]'"
  exit 1
fi
if [ %{gpdb_clients_version} = '%%{gpdb_clients_version}' ] ; then
  echo "The macro (variable) gpdb_clients_version must be supplied as rpmbuild ... --define='gpdb_clients_version [VERSION]'"
  exit 1
fi

%setup -q -c -n %{name}-%{gpdb_clients_version}

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
# handle properly if /usr/local/greenplum-db-clients already exists
ln -sT $RPM_INSTALL_PREFIX/%{name}-%{gpdb_clients_version} $RPM_INSTALL_PREFIX/%{name} || true
# Update greenplum_clients_path.sh for ${bin_gpdb}
sed -i -e "1 s~^\(GPHOME_CLIENTS=\).*~\1$RPM_INSTALL_PREFIX/%{name}-%{gpdb_clients_version}~" $RPM_INSTALL_PREFIX/%{name}-%{gpdb_clients_version}/greenplum_clients_path.sh

%postun
if [[ $(readlink $RPM_INSTALL_PREFIX/%{name}) == $RPM_INSTALL_PREFIX/%{name}-%{gpdb_clients_version} ]]; then
  unlink $RPM_INSTALL_PREFIX/%{name}
fi
