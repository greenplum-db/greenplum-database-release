# Greenplum Database Release

A repository for code related to creating packages of the [Greenplum Server](https://github.com/greenplum-db/gpdb).

Currently this mostly consists of a Concourse based application (task yaml, task scripts) that is capable of taking as input a binary tarball (bin_gpdb.tar.gz) and creating either an RPM or DEB package.

## Packaging Specifications

The full behavior and user experience of the packages involves many code bases and components coming together. The following is documentation that captures in one location the topics relates to a Greenplum Server package.

1. [Greenplum Server RPM Packaging Specification](Greenplum-Server-RPM-Packaging-Specification.md)

## How to use the application to create a RPM package locally

1.For rhel6
```bash
BIN_GPDB_TARGZ=/path/to/bin_gpdb.tar.gz CENTOS_VERSION=6 make local-build-rpm
```
The output like:
```
Creating Centos6 RPM Package...
Cloning into '/tmp/create-package/greenplum-database-release'...
...
...
Complete!
Passed check! Install /tmp/build/gpdb_rpm_installer/greenplum-db-<gpdb_version>-rhel6-x86_64.rpm package successfully.
```

2.For rhel7
```bash
BIN_GPDB_TARGZ=/path/to/bin_gpdb.tar.gz CENTOS_VERSION=7 make local-build-rpm
```
The output like:
```
Creating Centos7 RPM Package...
Cloning into '/tmp/create-package/greenplum-database-release'...
...
...
Complete!
Passed check! Install /tmp/build/gpdb_rpm_installer/greenplum-db-<gpdb_version>-rhel7-x86_64.rpm package successfully.
```

## How to use the application to create a DEB package locally
```bash
BIN_GPDB_TARGZ=/path/to/bin_gpdb.tar.gz make local-build-deb
```
The output like:
```
Creating DEB Package...
Cloning into '/tmp/create-package/greenplum-database-release'...
...
...
done.
Passed check! Install /tmp/build/gpdb_deb_installer/greenplum-db-<gpdb_version>-ubuntu18.04-amd64.deb package successfully.
```