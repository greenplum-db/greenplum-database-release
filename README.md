# Greenplum Database Release

A repository for code related to creating packages of the [Greenplum Server](https://github.com/greenplum-db/gpdb).

Currently this mostly consists of a Concourse based application (task yaml, task scripts) that is capable of taking as input a binary tarball (bin_gpdb.tar.gz) and creating either an RPM or DEB package.

## Packaging Specifications

The full behavior and user experience of the packages involves many code bases and components coming together. The following is documentation that captures in one location the topics relates to a Greenplum Server package.

1. [Greenplum Server RPM Packaging Specification](Greenplum-Server-RPM-Packaging-Specification.md)
