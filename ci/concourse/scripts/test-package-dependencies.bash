#!/bin/bash

set -exo pipefail

export GPDB_PKG_PATH="gpdb_pkg_installer"

if [[ $PLATFORM == "rhel"* ]]; then

	if [[ $PLATFORM == "rhel6" ]]; then
		# add repo configuration for vault.centos.org
		cp greenplum-database-release/ci/concourse/scripts/CentOS6.10-Vault.repo /etc/yum.repos.d/
		# disable base repo
		sed -i -E -e 's/\[(base|updates|extras)\]/[\1]\nenabled=0/' /etc/yum.repos.d/CentOS-Base.repo
	fi

	if [[ $PLATFORM == "rhel8" ]]; then
		dnf update && dnf install -y subscription-manager
		subscription-manager register --username=${RHEL_USER_NAME} --password=${RHEL_PASSWORD}
		subscription-manager attach --auto
	fi

	# Install file command
	yum install -y file
	# Install greenplum rpm
	yum install -y ${GPDB_PKG_PATH}/*.rpm

	if [[ $PLATFORM == "rhel8" ]]; then
		subscription-manager remove --all
		subscription-manager unregister
		subscription-manager clean
		# Remove entitlements and Subscription Manager configs
		rm -rf /etc/pki/entitlement
		rm -rf /etc/rhsm
	fi

	if [[ $CLIENTS == "clients" ]]; then
		source /usr/local/greenplum-db-clients/greenplum_clients_path.sh
		export GPHOME=$GPHOME_CLIENTS
	else
		source /usr/local/greenplum-db/greenplum_path.sh
	fi

elif [[ $PLATFORM == "ubuntu"* ]]; then
	apt-get --quiet update
	# Install file command
	apt-get --quiet=8 --yes install file

	pushd ${GPDB_PKG_PATH}
	# Install greenplum deb
	apt-get --quiet=8 --yes install ./*.deb
	if [[ $CLIENTS == "clients" ]]; then
		source /usr/local/greenplum-db-clients/greenplum_clients_path.sh
		export GPHOME=$GPHOME_CLIENTS
	else
		source /usr/local/greenplum-db/greenplum_path.sh
	fi
	popd
fi

# Get all file names in $GPHOME directory excluding python2.7 directory
file_names=($(find "${GPHOME}" -path "${GPHOME}"/ext/python/lib/python2.7 -prune -o -type f))

# For each file name, check if the file is of type 'ELF'
libraries=($(echo ${file_names[*]} | xargs file | grep ELF | awk -F':' '{print $1}'))

# Run 'ldd' on the libraries to check for missing dependencies
missing_deps=($(echo ${libraries[*]} | xargs ldd | grep "not found" | cut -d " " -f 1)) || true

for j in "${missing_deps[@]}"; do
	# Ignore the following missing dependencies
	if [[ $j != "libgpbsa.so" && $j != "libperl.so" && $j != "libdes425.so.3" ]]; then
		echo "Shared library $j missing"
		exit 1
	fi
done
