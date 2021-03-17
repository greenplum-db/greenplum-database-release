# Greenplum Database Release

This repository contains 3 different topics that support packaging and distribution of [Greenplum Database](https://greenplum.org) based on the source code of the Greenplum Database Server available at [github.com/greenplum-db/gpdb](https://github.com/greenplum-db/gpdb).

1. RPM Spec files and Debian Control files used for creating RPM and DEB packages of the Greenplum Database Server
2. An application that can be used with the RPM Spec or Debian Control files and a compiled archive of the Greenplum Server to create a package. This application supports both local use and in a Concourse pipeline.
3. The Concourse pipeline used to compile, package, and distribute new releases of Greenplum Database to various locations.

**Table of Contents**

1. [Greenplum Database Server RPM and DEB files](#greenplum-database-server-rpm-and-deb-files)
	1. [Packaging Specification and Behavior](#packaging-specification-and-behavior)
2. [Build RPM and DEB from compiled archive](#build-rpm-and-deb-from-compiled-archive)
	1. [Locally](#locally)
	2. [Concourse](#concourse)
3. [Greenplum Database Concourse release pipeline](#greenplum-database-concourse-release-pipeline)

## Greenplum Database Server RPM and DEB files

### Packaging Specification and Behavior

The full behavior and user experience of the packages involves many code bases and components coming together. The following is documentation that captures in one location the specification and behavior of a Greenplum Database Server package.

1. [Greenplum Database Server RPM Packaging Specification](Greenplum-Database-Server-RPM-Packaging-Specification.md)

## Build RPM and DEB from compiled archive

**Support Matrix**

_Concourse Builds_
| Platform     | Greenplum Major Version |
| ------------ | ----------------------- |
| Centos 6, 7  | 5, 6, 7                 |
| Ubuntu 18.04 | 6, 7                    | 

_Local Builds_
| Platform     | Greenplum Major Version |
| ------------ | ----------------------- |
| Centos 6, 7  | 4, 5, 6, 7              |
| Ubuntu 18.04 | 5, 6, 7                 | 

_If it's not listed in the table, it's not supported._

### Locally

Create a RPM package locally for a given tarball of the Server, a platform, and a version.

```bash
export BIN_GPDB_TARGZ=[Path to bin_gpdb.tar.gz]
export CENTOS_VERSION=[Major Version Number]
export GPDB_VERSION=[Version String]
make local-build-gpdb-rpm
```

Create a DEB package locally for a given tarball of the Server, and version.

**Note:** When building Greenplum 5 debian packages, the `yq` utility is required. Please refer to the [installation guide](https://github.com/mikefarah/yq#install)

```bash
export BIN_GPDB_TARGZ=[Path to bin_gpdb.tar.gz]
export GPDB_VERSION=[Version String]
make local-build-gpdb-deb
```

### Concourse

A Concourse task yaml and accompanying scripts is provided to allow creation of packages in a Concourse pipelines.

(RPM Only): **Greenplum 6 and 7** uses the `ci/concourse/tasks/build_gpdb.rpm.yml` and **Greenplum 5** uses `ci/concourse/tasks/build_gpdb5_rpm.yml` for building RPM packages.
(DEB Only): **Greenplum 6 and 7** uses the `ci/concourse/tasks/build_gpdb_deb.yml` (refer to optional `gpdb_src` task input below.

#### Task Inputs

- `greenplum-database-release/` = concourse volume containing this repository in order to retrieve the scripts to do the packaging
- `bin_gpdb`: folder contains single tarball with pattern `*.tar.gz`, which is the binary of compiled code
- `license_file`: folder contains license file with pattern `*.txt`

Optional:
- `gpdb_src`: the optional folder containing source code of the Greenplum. It's only used for OSS (open-source software) packaging. It used to retrieve `LICENSE`, `COPYRIGHT` files.

#### Task Outputs

(RPM Only): `gpdb_rpm_installer/`: the produced rpm file will be put under this folder.
(DEB Only): `gpdb_deb_installer/`: the output Debian package will put under this folder

#### Task Paramaters

Required Concourse task environment paramaters:

- `GPDB_OSS`: whether we are building an OSS version of the package, if not defined, it's `false`. If this value is `true`, `gpdb_src` folder has to be provided with `LICENSE` and `COPYRIGHT` files.
- `GPDB_LICENSE`: the name of the license the Greenplum is distributed under, it's currently `VMware Software EULA`
- `GPDB_URL`: the URL for more information about Greenplum, it's currently `https://github.com/greenplum-db/gpdb` for OSS, and `https://network.tanzu.vmware.com/products/pivotal-gpdb/` for enterprise
- (RPM Only) `GPDB_NAME`: the package name, e.g. `greenplum-db-6` for `GP6`, or `greenplum-db-7` for `GP7`, or `greenplum-db-5` for `GP5`.
- (RPM Only) `PLATFORM`: `rhel6`, `rhel7`. This should depend on which `image` used to package the software
- (RPM Only) `GPDB_RELEASE`: the number of time this version of Greenplum is released. Unless package same version multiple times, it should be `1`.
- (DEB Only) `GPDB_NAME`: use only `greenplum-db`.
- (DEB Only) `GPDB_BUILDARCH`: target architecture, default is `amd64`
- (DEB Only) `GPDB_DESCRIPTION`: long description of this package, default is `Pivotal Greenplum Server`
- (DEB Only) `GPDB_PREFIX`: installation location of this package, default is `/usr/local/`

#### Task Environment

A Docker environment must be used that contains the necessary build tools for either RPM or DEB package building. Image that support this can be found in [gp-image-baking](https://github.com/pivotal/gp-image-baking).

#### Example

```yaml
- task: create_gpdb_rpm_package
    file: greenplum-database-release/ci/concourse/tasks/build-gpdb-rpm.yml
    image: gpdb6-centos6-build
    input_mapping:
      bin_gpdb: bin_gpdb_centos6
    params:
      PLATFORM: "rhel6"
      GPDB_NAME: greenplum-db-6
      GPDB_RELEASE: 1
      GPDB_LICENSE: VMware Software EULA
      GPDB_URL: https://github.com/greenplum-db/gpdb
      GPDB_OSS: true
```

## Greenplum Database Concourse release pipeline

A Concourse pipeline application that builds, integrates, packages, and distributes a release of Greenplum Database 6. 

**Dependencies**

Access to https://prod.ci.gpdb.pivotal.io/

**Installation**

```bash
make set-prod
```

**Development**

```bash
make set-dev
```

