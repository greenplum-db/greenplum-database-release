# Greenplum Database Release

A repository for code related to creating packages of the [Greenplum Server](https://github.com/greenplum-db/gpdb).

Currently this mostly consists of a Concourse based application (task yaml, task scripts) that is capable of taking as input a binary tarball (bin_gpdb.tar.gz) and creating either an RPM or DEB package.

## Pipeline Setup

| | |
|-|-|
| Name: | greenplum-database-release |
| Exposed: | No |
| Production: | `make set-prod` |
| Developer: | `make set-dev` |

## Packaging Specifications

The full behavior and user experience of the packages involves many code bases and components coming together. The following is documentation that captures in one location the topics relates to a Greenplum Server package.

1. [Greenplum Server RPM Packaging Specification](Greenplum-Server-RPM-Packaging-Specification.md)

## How to use the application to create a RPM package locally

1.For rhel6
```bash
BIN_GPDB_TARGZ=/path/to/bin_gpdb.tar.gz make local-build-gpdb6-centos6-rpm
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
BIN_GPDB_TARGZ=/path/to/bin_gpdb.tar.gz make local-build-gpdb6-centos7-rpm
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

## How to use the application to create a GPDB6 DEB package locally
```bash
BIN_GPDB_TARGZ=/path/to/bin_gpdb.tar.gz make local-build-gpdb6-deb
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

## How to use the application to create a RPM package for gpdb5 locally

For rhel6

```bash
GPDB_VERSION=<GPDB_VERSION> BIN_GPDB_TARGZ=<path-to-tar-archive> make local-build-gpdb5-centos6-rpm
```

For rhel7

```bash
GPDB_VERSION=<GPDB_VERSION> BIN_GPDB_TARGZ=<path-to-tar-archive> make local-build-gpdb5-centos7-rpm
```

## How to use the open source code to create a GPDB5 source DEB package locally

1. Install yq, please refer to the [installation guide](https://github.com/mikefarah/yq#install)
2. ```make local-build-gpdb5-deb```

The output like:
```
Creating DEB Package...
...
...
Done. Please find the source package under /tmp/build/debian_source_files
```
