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

[Greenplum Server RPM Packaging Specification](Greenplum-Server-RPM-Packaging-Specification.md)

## Build a RPM package locally

Create a RPM package locally for a given tarball of the Server, platform, and Version.

### Configuration

```bash
export BIN_GPDB_TARGZ=/path/bin/bin_gpdb.tar.gz
export CENTOS_VERSION=7
export GPDB_VERSION=6.x.x
```

### Execution

```bash
make local-build-gpdb-rpm
```

## Build a DEB package locally

Create a DEB package locally for a given tarball of the Server, and version. It is not specific to the version of Ubuntu.

**Note:** When building Greenplum 5 debian packages, the `yq` utility is required. Please refer to the [installation guide](https://github.com/mikefarah/yq#install)

### Configuration

```bash
export BIN_GPDB_TARGZ=/path/bin/bin_gpdb.tar.gz
export GPDB_VERSION=6.x.x
```

### Execution

```bash
make local-build-gpdb6-deb
```
