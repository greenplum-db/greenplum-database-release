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

## RPM packaging through concourse pipeline

There are following packages created by the concourse [pipeline](https://github.com/greenplum-db/greenplum-database-release/blob/master/ci/concourse/pipelines/gpdb_opensource_release.yml):
- RPM packages of `greenplum-db-6` for `RHEL6` and `RHEL7`

Resource [`gpdb_rpm_installer_centos6`](https://github.com/greenplum-db/greenplum-database-release/blob/master/ci/concourse/pipelines/gpdb_opensource_release.yml#L140) is the resource for `GP6` on `RHEL6`
, and resource [`gpdb_rpm_installer_centos7`](https://github.com/greenplum-db/greenplum-database-release/blob/master/ci/concourse/pipelines/gpdb_opensource_release.yml#L165) is the resource for `GP6` on `RHEL7`

Job `rhel6 packaging` task [`create_gpdb_rpm_package`](https://github.com/greenplum-db/greenplum-database-release/blob/master/ci/concourse/pipelines/gpdb_opensource_release.yml#L285) builds the `greenplum-db-6` (aka `GP6`) RPM package for `RHEL6`.
, and job `rhel7 packaging` task [`create_gpdb_rpm_package`](https://github.com/greenplum-db/greenplum-database-release/blob/master/ci/concourse/pipelines/gpdb_opensource_release.yml#L315) builds the `greenplum-db-6` RPM package for `RHEL7`.
They are both using task [`build_gpdb_rpm`](https://github.com/greenplum-db/greenplum-database-release/blob/master/ci/concourse/tasks/build_gpdb_rpm.yml) to build RPM packages.

### Concourse job description

Here are the details of each concourse job and related resources to product each package.

#### `build_gpdb_rpm.yml` task for `GP6` and `GP7`

Here is a code snippet to use [`build_gpdb_rpm`](https://github.com/greenplum-db/greenplum-database-release/blob/master/ci/concourse/tasks/build_gpdb_rpm.yml):

```yaml
- task: create_gpdb_rpm_package
    file: greenplum-database-release/ci/concourse/tasks/build_gpdb_rpm.yml
    image: gpdb6-centos6-build
    input_mapping:
      bin_gpdb: bin_gpdb_centos6
    params:
      PLATFORM: "rhel6"
      GPDB_NAME: greenplum-db-6
      GPDB_RELEASE: 1
      GPDB_LICENSE: Pivotal Software EULA
      GPDB_URL: https://github.com/greenplum-db/gpdb
      GPDB_OSS: true
```

These are the required inputs of this task:
- `image`: docker image with provided toolchain to package the build
- `bin_gpdb`: folder contains single tarball with pattern `*.tar.gz`, which is the binary of compiled code
- `license_file`: folder contains license file with pattern `*.txt`
- environment variables coming as `params`:
  - `GPDB_NAME`: the package name, e.g. `greenplum-db-6` for `GP6`, or `greenplum-db-7` for `GP7`.
  - `GPDB_OSS`: whether we are building an OSS version of the package, if not defined, it's `false`. If this value is `true`, `gpdb_src` folder has to be provided with `LICENSE` and `COPYRIGHT` files.
  - `PLATFORM`: `rhel6` or `rhel7`. This should depend on which `image` used to package the software
  - `GPDB_RELEASE`: the number of time this version of Greenplum is released. Unless package same version multiple times, it should be `1`.
  - `GPDB_LICENSE`: the name of the license the Greenplum is distributed under, it's currently `Pivotal Software EULA`
  - `GPDB_URL`: the URL for more information about Greenplum, it's currently `https://github.com/greenplum-db/gpdb` for OSS, and `https://network.pivotal.io/products/pivotal-gpdb/` for enterprise

Dependency:
- `greenplum-database-release/`: folder point to this repo to retrieve the scripts to do the packaging.
- `ci/concourse/scripts/build_gpdb_rpm.py`: python script that actually does the packaging. It depends on `python3` and libraries in `ci/concourse/oss`.
- `ci/concourse/scripts/${GPDB_NAME}.spec`: the RPM spec file for given package specified by `${GPDB_NAME}`.

Optional:
- `gpdb_src`: the optional folder containing source code of the Greenplum. It's only used for OSS (open-source software) packaging. It used to retrieve `LICENSE`, `COPYRIGHT` files.

Output:
- `gpdb_rpm_installer/`: the produced rpm file will be put under this folder.

##### Examples

For `greenplum-db-7` RPM OSS package on `rhel7`
- `image`: should point to `pivotaldata/gpdb7-centos7-build:latest` docker image
- `bin_gpdb`: should point to binary tarball of `GP7`, e.g. `bin_gpdb.tar.gz`
- `license_file`: can reuse `osl/released/gpdb6/open_source_license_greenplum-database-6.0.0-97773a0-(.*).txt` for now until a new license file for `GP7`
- `params`
  - `GPDB_NAME`: should be `greenplum-db-7`
  - `GPDB_OSS`: should be `true`
  - `PLATFORM`: should be `rhel7`
  - rest of them using the values mentioned above


For `greenplum-db-6` RPM OSS package on `rhel6`
- `image`: should point to `pivotaldata/gpdb6-centos6-build:latest` docker image
- `bin_gpdb`: should point to binary tarball of `GP6`, e.g. `bin_gpdb.tar.gz`
- `license_file`: should point to `osl/released/gpdb6/open_source_license_greenplum-database-6.0.0-97773a0-(.*).txt`
- `params`
  - `GPDB_NAME`: should be `greenplum-db-6`
  - `GPDB_OSS`: should be `true`
  - `PLATFORM`: should be `rhel6`
  - rest of them using the values mentioned above

#### `build_gpdb5_rpm.yml` for `GP5`

This task is similar to the `build_gpdb_rpm.yml`, but depends on bash script `build_gpdb5_rpm.sh`, other than Python code `build_gpdb_rpm.py`.

These are the required inputs of this task:
- `image`: same as above
- `bin_gpdb`: same as above
- environment variables coming as `params`:
  - `GPDB_NAME` the package name, e.g. `greenplum-db-5` for `GP5`
  - `PLATFORM`: same as above
  - `GPDB_RELEASE`: same as above
  - `GPDB_VERSION`: optional, by default it will derive from `gpdb_src/getversion`
  - `GPDB_LICENSE`: same as above
  - `GPDB_URL`: same as above

##### Examples

For `greenplum-db-5` RPM enterprise package on `rhel7`
- `image`: should point to `pivotaldata/centos-gpdb-dev:7-gcc6.2-llvm3.7` docker image.
- `bin_gpdb`: should point to binary tarball of `GP5`, e.g. `bin_gpdb.tar.gz`.
- `params`
  - `GPDB_NAME`: should be `greenplum-db-5`
  - `PLATFORM`: should be `rhel7`
  - `GPDB_URL`: should be `https://network.pivotal.io/products/pivotal-gpdb/`
  - rest of them using the values mentioned above

## Debian package through concourse pipeline

Job `ubuntu18.04 packaging` task [`create_gpdb_deb_package`](https://github.com/greenplum-db/greenplum-database-release/blob/master/ci/concourse/pipelines/gpdb_opensource_release.yml#L345) builds the debian package `greenplum-db` for `GP6` in current [pipeline](https://github.com/greenplum-db/greenplum-database-release/blob/master/ci/concourse/pipelines/gpdb_opensource_release.yml).
It's using task [`build_gpdb_deb.yml`](https://github.com/greenplum-db/greenplum-database-release/blob/master/ci/concourse/tasks/build_gpdb_deb.yml) to build the Debian package.

### `build_gpdb_deb.yml` task for Debian packaging

Here is a code snippet to use the `build_gpdb_deb.yml`:

```yaml
  - task: create_gpdb_deb_package
    file: greenplum-database-release/ci/concourse/tasks/build_gpdb_deb.yml
    image: gpdb6-ubuntu18.04-build
    input_mapping:
      bin_gpdb: bin_gpdb_ubuntu18.04
    params:
      PLATFORM: "ubuntu18.04"
      GPDB_OSS: true
```

These are the required inputs for this task:
- `image`: container image with toolchain to build Debian package.
- `bin_gpdb`: folder with `*.tar.gz` tarball
- `license_file`: the optional folder contains license file with pattern `*.txt`
- `params` environment variables:
  - `PLATFORM`:
  - `GPDB_NAME`: the prefix of the package name, default is `greenplum-db`. Depends on the major version of the software, it could be `greenplum-db-6` for 6.X and `greenplum-db-7` for 7.X.
  - `GPDB_URL`: URL location of upstream software, default is `https://github.com/greenplum-db/gpdb`
  - `GPDB_BUILDARCH`: target architecture, default is `amd64`
  - `GPDB_DESCRIPTION`: long description of this package, default is `Pivotal Greenplum Server`
  - `GPDB_PREFIX`: installation location of this package, default is `/usr/local`
  - `GPDB_OSS`: `true` to build OSS package, `false` otherwise. When build OSS package, `LICENSE` and `COPYRIGHT` are copied from `gpdb_src` folder, and `NOTICE` file is generated under `/usr/share/doc/greenplum-db` folder.

Dependency:
- `greenplum-database-release/`: the folder points to this repo to retrieve the scripts to do the packaging.
- `ci/concourse/scripts/build_gpdb_deb.bash`: the bash script that actually does the packaging.

Output:
- `gpdb_deb_installer/`: the output Debian package will put under this folder

## Build a RPM package locally

Create a RPM package locally for a given tarball of the Server, platform, and Version.

Support for **Centos 6/7** and **Greenplum 4/5/6/7**.

### Configuration

```bash
export BIN_GPDB_TARGZ=[Path to bin_gpdb.tar.gz]
export CENTOS_VERSION=[Major Version Number]
export GPDB_VERSION=[Version String]
```

### Execution

```bash
make local-build-gpdb-rpm
```

## Build a DEB package locally

Create a DEB package locally for a given tarball of the Server, and version. It is not specific to the version of Ubuntu.

Support for **Ubuntu 18.04** and **Greenplum 5/6/7**.

**Note:** When building Greenplum 5 debian packages, the `yq` utility is required. Please refer to the [installation guide](https://github.com/mikefarah/yq#install)

### Configuration

```bash
export BIN_GPDB_TARGZ=[Path to bin_gpdb.tar.gz]
export GPDB_VERSION=[Version String]
```

### Execution

```bash
make local-build-gpdb-deb
```
