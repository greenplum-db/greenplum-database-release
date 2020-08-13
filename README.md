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

Remember the tarball to be used for the build
```console
export BIN_GPDB_TARGZ=/path/bin/bin_gpdb.tar.gz
```

### for CentOs 7

```console
export CENTOS_VERSION=7

GPDB_VERSION=6.x.x make local-build-gpdb-rpm
```

### for CentOs 6

Just change the `CENTOS_VERSION` to `6`, like:

```console
export CENTOS_VERSION=6
```

## Build a DEB package locally

## for GP6 using binary tarball

```console
export BIN_GPDB_TARGZ=/path/to/bin_gpdb.tar.gz

GPDB_VERSION=6.x.x make local-build-gpdb6-deb
```

## for GP5 using source code

`yq` is required, please refer to the [installation guide](https://github.com/mikefarah/yq#install)

```console
GPDB_VERSION=5.x.x make local-build-gpdb5-deb
```