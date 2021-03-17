# Greenplum Server RPM Packaging Specification

Description of the expected behavior as it relates to RPM packaging for the Greenplum Server component

1. [Supported Features](#supported-features)
2. [Detailed Package Behavior](#detailed-package-behavior)
   1. [_Packaging Layer_](#_packaging-layer_)
   2. [_Greenplum Path Layer_](#_greenplum-path-layer_)
   3. [_Runtime Linking Layer_](#_runtime-linking-layer_)
3. [Usage](#usage)
   1. [How to perform an installation](#how-to-perform-an-installation)
   2. [How to perform a Minor or Maintenance Version Upgrade](#how-to-perform-a-minor-or-maintenance-version-upgrade)
   3. [How to perform a Major version upgrade](#how-to-perform-a-major-version-upgrade)
   4. [How to perform a Minor or Maintenance version downgrade](#how-to-perform-a-minor-or-maintenance-version-downgrade)
   5. [How to perform an uninstallation](#how-to-perform-an-uninstallation)
   6. [How to perform an installation to a non-default location](#how-to-perform-an-installation-to-a-non-default-location)
4. [Symbolic Links and Installation Directory](#symbolic-links-and-installation-directory)
   1. [Greenplum 5 Current Behavior](#greenplum-5-current-behavior)
   2. [Greenplum 6 Current Behavior](#greenplum-6-current-behavior)
   3. [Expected Behavior for All Major Versions](#expected-behavior-for-all-major-versions)

## Supported Features

1. All of the basic functionality offered by the RPM specifications

2. The package installation root is relocatable.

   Some users have IT and platform requirements regarding where software is installed. The default installation directory is `/usr/local/` but it can be changed during installation by using `rpm --prefix=[dir]`. Note: When using **rpm** for package installation, automatic dependency resolution does not occur.

3. Packages of different major versions can be installed at the same time.

   Data migration for a Major version upgrade require both major versions to be installed. Additionally, some users may wish to simultanously run multiple versions of Greenplum concurrently or otherwise with the ability to easily choose a different version of Greenplum. The package names are suffixed with a major version number, which prevents conflict and allows both `greenplum-db-5` and `greenplum-db-6` to be installed simultaneously.

4. Packages of different minor or patch version numbers can be installed at the same time using `rpm --install`

   Some users may wish to simultanously run multiple versions of Greenplum concurrently or otherwise with the ability to easily choose a different version of Greenplum. Note: When using **rpm** for package installation, automatic dependency resolution does not occur.

5. A symbolic link is created that points to the most recently installed Greenplum

   Users configure environments and tools to be Greenplum version inspecific by relying on a symbolic link to the Greenplum installation.

## Detailed Package Behavior

### _Packaging Layer_

- The `Name` metadata field of the RPM package shall be `greenplum-db-[x]`, such that `[x]` is the Greenplum Major version number
- The filename of the resulting file shall be `greenplum-db-[x.y.z]-[PLATFORM]-x86_64.rpm`, such that `[x.y.z]` is the Greenplum Server version string and `[PLATFORM]` is one of `rhel6`, `rhel7`, `sles11`, `sles12`
- The package shall make any installed `greenplum-db` package, of the same Major version, obsolete upon installation. Examples:
  - If `greenplum-db` version `5.0.0` is installed, then a user installs `greenplum-db-6` version `6.0.0`, both packages shall remain installed
  - If `greenplum-db` version `6.0.0` is installed, then a user installs `greenplum-db-6` version `6.0.0`, only `greenplum-db-6` version `6.0.0` shall remain installed
  - If `greenplum-db` version `6.0.0` is installed, then a user installs `greenplum-db-6` version `6.0.1`, only `greenplum-db-6` version `6.0.1` shall remain installed
- The package shall by default be installed at `/usr/local/greenplum-db-[package version]` (Note: this is not the same as `/usr/local/[package-name]-[package-version]`)
- The package shall be named based on [Greenplum Filename Specifications](https://github.com/pivotal/gp-releng/blob/main/docs/Greenplum-Filename-Specifications.md)
- The package shall be [relocatable](http://ftp.rpm.org/api/4.4.2.2/relocatable.html)
- The package shall create a symbolic link from `${installation prefix}/greenplum-db-[package-version]` to `${installation prefix}/greenplum-db`
  - If a `${installation prefix}/greenplum-db` symbolic link already exists, then it should be removed and the expected link created
- When performing an upgrade, downgrade, or uninstall of the RPM package, if a user has made any changes to `${installation prefix}/greenplum-db-[package-version]/greenplum_path.sh`, then the file shall not be removed or overwritten.

### _Greenplum Path Layer_

- `greenplum-path.sh` shall be installed to `${installation prefix}/greenplum-db-[package-version]/greenplum_path.sh`
- `${GPHOME}` shall be set to `%{installation prefix}/greenplum-db-[version]`
  - If the installation prefix for a package is changed from the default by a user, then `%{installation prefix}` shall be updated
- `${LD_LIBRARY_PATH}` shall be set to `${GPHOME}/lib:${PYTHONHOME}/lib:${LD_LIBRARY_PATH-}`
- For release where we vendor `python`, `${PYTHONHOME}` shall be set to `${GPHOME}/ext/python`
  - Whether or not `${PYTHONHOME}` is included in `greenplum_path.sh` will be determined at **build time** and not run-time
- `${PYTHONPATH}` shall be set to `${GPHOME}/lib/python`
- `${PATH}` shall be set to `${GPHOME}/bin:${PYTHONHOME}/bin:${PATH}`
- If the file `${GPHOME}/etc/openssl.cnf` exists then `${OPENSSL_CONF}` shall be set to `${GPHOME}/etc/openssl.cnf`
- No shebang (`#!)` will be set
- The contents of `greenplum_path.sh` shall be POSIX compatible
- The `greenplum_path.sh` file shall pass [ShellCheck](https://github.com/koalaman/shellcheck)

### _Runtime Linking Layer_

- Any of the `elf` formatted files within the package at `${GPHOME}/bin`, that relied on `${LD_LIBRARY_PATH}` being set for runtime linking, shall now rely on `${RUNPATH}` being set to `${ORIGIN}/../lib`
  - Exception: The following exceptions are golang binaries that shall not have `RUNPATH` set:
    - `bin/gpkafka` (Greenplum 6, Greenplum 5)
    - `bin/gpbackup_s3_plugin` (Greenplum 5)
    - `bin/gprestore` (Greenplum 5)
    - `bin/gpbackup` (Greenplum 5)
    - `bin/gpbackup_helper` (Greenplum 5)
- Any of the "elf" formatted files within the package at `${GPHOME}/ext/python/bin/`, that relied on `${LD_LIBRARY_PATH}` being set for runtime linking, shall now rely on `RUNPATH` being set to `${ORIGIN}/../lib`
- Any of the "elf" formatted files within the package at `${GPHOME}/lib/`, that relied on `${LD_LIBRARY_PATH}` being set for runtime linking, shall now rely on `RUNPATH` being set to `${ORIGIN}/../lib`
  - Exception (Greenplum 6): `${GPHOME}/lib/postgresql/quicklz_compressor.so` shall have its `RUNPATH` set to `${ORIGIN}/../../lib`
  - Exception (Greenplum 6, Greenplum 5): `${GPHOME}/lib/python/pygresql/_pg.so` shall have its `RUNPATH` set to `${ORIGIN}/../../../lib`
- (Greenplum 5): The `elf` formatted file `${GPHOME}/ext/python/lib/python2.7/lib-dynload/_hashlib.so`, that relied on `${LD_LIBRARY_PATH}` being set for runtime linking, shall now rely on `RUNPATH` being set to `${ORIGIN}/../../../../../lib`
- (Greenplum 5): The `elf` formatted files contained within the vendored krb5 dependency, that relied on `${LD_LIBRARY_PATH}` being set for runtime linking, shall now rely on `RUNPATH` being set to `${ORIGIN}/../lib`
- In all situations where `RUNPATH` is involved, if it is already set it shall be updated, if it is not set it shall be added
- When setting `${RUNPATH}` to the specified value, it **MUST** be done by setting the appropriate linker flags (e.g., `-Wl,-rpath,'$ORIGIN/../lib`) with the following exceptions:
  - (Greenplum 5) The `elf` formatted files contained within the vendored krb5 dependency will have its `RUNPATH` modified with `patchelf`

## Usage

Documenation of how a user is expected to to interact with the Greenplum Server package.

### How to perform an installation

1. Download the Greenplum Server binary RPM package installer from <https://network.tanzu.vmware.com>

2. Transfer the RPM package to all hosts being used for the Greenplum cluster

3. On every host, as a **root** user, install the RPM package. Any necessary dependencies will be automatically installed.

   ```sh
   yum install ./greenplum-db-[version]-[platform]-[arch].rpm
   ```

### How to perform a Minor or Maintenance Version Upgrade

1. Download the new Greenplum Server binary RPM package installer from <https://network.tanzu.vmware.com>

2. Transfer the RPM package to all hosts being used for the Greenplum cluster

3. On every host, as a **root** user, Upgrade the RPM package. Any necessary dependencies will be automatically installed.

   ```sh
   yum upgrade ./greenplum-db-[version]-[platform]-[arch].rpm
   ```

   **Note**: The previous installation directory may still exist if `greenplum_path.sh` was modified or extra Greenplum components installed

### How to perform a Major version upgrade

1. Download the new Greenplum Server binary RPM package installer from <https://network.tanzu.vmware.com>

2. Transfer the RPM package to all hosts being used for the Greenplum cluster

3. On every host, as a **root** user, Install the Greenplum RPM package. Any necessary dependencies will be automatically installed.

   ```sh
   yum install ./greenplum-db-[version]-[platform]-[arch].rpm
   ```

   **Note**: The previous Greenplum Major version installation directory will still exist

4. Follow the documented steps for [Migrating Data from Greenplum 4.3 or 5](https://gpdb.docs.pivotal.io/6-1/install_guide/migrate.html)

5. Uninstall the previous Greenplum Major version RPM package

   ```sh
   # If the Greenplum version is <= 5.28.0
   yum remove greenplum-db
   # If the Greenplum 5 version is > 5.28.0
   yum remove greenplum-db-[major version]
   ```

### How to perform a Minor or Maintenance version downgrade

1. Download the downgraded Greenplum Server binary RPM package installer from <https://network.tanzu.vmware.com>

2. Transfer the RPM package to all hosts being used for the Greenplum cluster

3. On every host, as a **root** user, downgrade the Greenplum RPM package.

   ```sh
   yum downgrade ./greenplum-db-[version]-[platform]-[arch].rpm
   ```

   **Note**: The previous Greenplum version installation directory may still exist

### How to perform an uninstallation

1. On every host, as a **root** user, uninstall the Greenplum RPM package.

   ```sh
   # If the Greenplum 5 versions is <= [XXX]
   yum remove greenplum-db
   # If the Greenplum 5 version is > [XXX]
   yum remove greenplum-db-5
   ```

### How to perform an installation to a non-default location

1. Download the Greenplum Server binary RPM package installer from <https://network.tanzu.vmware.com>

2. Transfer the RPM package to all hosts being used for the Greenplum cluster

3. On every host, as a **root** user, install any necessary dependencies

   ```sh
   yum deplist ./greenplum-db-[version]-[platform]-[arch].rpm
   yum install [dependencies]
   ```

4. On every host, as a **root** user, install the RPM package and specify the desired installation location

   ```sh
   rpm --install ./greenplum-db-[version]-[platform]-[arch].rpm --prefix=[desired installation location]
   ```

### How to install multiple Minor or Maintenance versions

1. Download the Greenplum Server binary RPM package installer from <https://network.tanzu.vmware.com>

2. Transfer the RPM package to all hosts being used for the Greenplum cluster

3. On every host, as a **root** user, install any necessary dependencies

   ```sh
   yum deplist ./greenplum-db-[version A]-[platform]-[arch].rpm
   yum deplist ./greenplum-db-[version B]-[platform]-[arch].rpm
   yum deplist ./greenplum-db-[version C]-[platform]-[arch].rpm
   yum install [dependencies]
   ```

4. On every host, as a **root** user, install the RPM package with `rpm --install`

   ```sh
   rpm --install ./greenplum-db-[version A]-[platform]-[arch].rpm
   rpm --install ./greenplum-db-[version B]-[platform]-[arch].rpm
   rpm --install ./greenplum-db-[version C]-[platform]-[arch].rpm
   ```

### How to install Greenplum without Root access

It is not advisable to install Greenplum without root access. If necessary, there are two methods:

#### Method 1 - Using rpm2cpio

1. Download the Greenplum Server binary RPM package installer from <https://network.tanzu.vmware.com>

2. Transfer the RPM package to all hosts being used for the Greenplum cluster

3. On every host, ensure any necessary dependencies are installed

   ```sh
   yum deplist ./greenplum-db-[version]-[platform]-[arch].rpm
   ```

4. On every host, as a **non-root** user, extract the RPM package and specify the desired installation location

   ```sh
   rpm2cpio ./greenplum-db-[version]-[platform]-[arch].rpm | cpio -D /install/directory -idmv
   ```

All package management, dependency resolution, and conflict management with other software installed on the system will not be available with this method.

#### Method 2 - Separate RPM package database

1. Download the Greenplum Server binary RPM package installer from <https://network.tanzu.vmware.com>

2. Transfer the RPM package to all hosts being used for the Greenplum cluster

3. On every host, ensure any necessary dependencies are installed

   ```sh
   yum deplist ./greenplum-db-[version A]-[platform]-[arch].rpm
   yum deplist ./greenplum-db-[version B]-[platform]-[arch].rpm
   yum deplist ./greenplum-db-[version C]-[platform]-[arch].rpm
   ```

4. On every host, as a **non-root** user, follow the Redhat solution for installing RPM packages without root permissions:  <https://access.redhat.com/solutions/2986251>

The method can cause issue and conflicts with the rpm databse which will cause system to misbehave and leave the system in unstable state. Red Hat doesn't support any rpm database to be kept separate other than from /var/lib/rpm.

## Symbolic Links and Installation Directory

### Greenplum 5 Current Behavior

#### Install

```console
$ yum install -y -d0 ./greenplum-db-5.27.0-rhel7-x86_64.rpm

$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /usr/local/greenplum-db-5.27.0
drwxr-xr-x root root greenplum-db-5.27.0
```

#### Upgrade

```console
$ yum install -y -d0 ./greenplum-db-5.27.0-rhel7-x86_64.rpm

# Same behavior between 'upgrade' and 'install'
$ yum upgrade -y -d0 ./greenplum-db-5.27.1-rhel7-x86_64.rpm

# Missing expected symlink
$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
drwxr-xr-x root root greenplum-db-5.27.0
drwxr-xr-x root root greenplum-db-5.27.1

# Unexpected symlink
# Directory is empty except for symlink
$ ls -l /usr/local/greenplum-db-5.27.0/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'}
lrwxrwxrwx root root greenplum-db-5.27.1 -> /usr/local/greenplum-db-5.27.1
```

#### Downgrade

```console
$ yum install -y -d0 ./greenplum-db-5.27.0-rhel7-x86_64.rpm

$ yum upgrade -y -d0 ./greenplum-db-5.27.1-rhel7-x86_64.rpm

$ yum downgrade -y -d0 ./greenplum-db-5.27.0-rhel7-x86_64.rpm

# Missing expected symlink
$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
drwxr-xr-x root root greenplum-db-5.27.0

# Unexpected symlink
$ ls -l /usr/local/greenplum-db-5.27.0/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep greenplum-db
lrwxrwxrwx root root greenplum-db-5.27.1 -> /usr/local/greenplum-db-5.27.1
```

#### Relocated Install

```console
$ rpm -i ./greenplum-db-5.27.0-rhel7-x86_64.rpm --prefix=/opt
$ ls -l /opt/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /opt/greenplum-db-5.27.0
drwxr-xr-x root root greenplum-db-5.27.0
```

#### Relocated Upgrade

```console
$ rpm -i ./greenplum-db-5.27.0-rhel7-x86_64.rpm --prefix=/opt

$ rpm -U ./greenplum-db-5.27.1-rhel7-x86_64.rpm --prefix=/opt

# Missing expected symlink
$ ls -l /opt | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
drwxr-xr-x root root greenplum-db-5.27.0
drwxr-xr-x root root greenplum-db-5.27.1

# Unexpected symlink
$ ls -l /opt/greenplum-db-5.27.0/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'}
lrwxrwxrwx root root greenplum-db-5.27.1 -> /opt/greenplum-db-5.27.1
```

#### Relocated Downgrade

```console
$ rpm -i ./greenplum-db-5.27.0-rhel7-x86_64.rpm --prefix=/opt

$ rpm -U ./greenplum-db-5.27.1-rhel7-x86_64.rpm --prefix=/opt

$ rpm -U --oldpackage ./greenplum-db-5.27.0-rhel7-x86_64.rpm --prefix=/opt

# Missing expected symlink
$ ls -l /opt/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
drwxr-xr-x root root greenplum-db-5.27.0

# Unexpected symlink
$ ls -l /opt/greenplum-db-5.27.0/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep greenplum-db
lrwxrwxrwx root root greenplum-db-5.27.1 -> /opt/greenplum-db-5.27.1
```

#### Dual Install (same package major version)

```console
$ rpm -i ./greenplum-db-5.27.0-rhel7-x86_64.rpm

$ rpm -i ./greenplum-db-5.27.1-rhel7-x86_64.rpm

# Symlink exists for previous version
$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /usr/local/greenplum-db-5.27.0
drwxr-xr-x root root greenplum-db-5.27.0
drwxr-xr-x root root greenplum-db-5.27.1

# Unexpected symlink
$ ls -l /usr/local/greenplum-db-5.27.0/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep greenplum-db
lrwxrwxrwx root root greenplum-db-5.27.1 -> /usr/local/greenplum-db-5.27.1
```

#### Relocated Dual Install (same package major version)**

```console
$ rpm -i ./greenplum-db-5.27.0-rhel7-x86_64.rpm --prefix=/opt

$ rpm -i ./greenplum-db-5.27.1-rhel7-x86_64.rpm --prefix=/opt

# Symlink exists for previous version
$ ls -l /opt/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /opt/greenplum-db-5.27.0
drwxr-xr-x root root greenplum-db-5.27.0
drwxr-xr-x root root greenplum-db-5.27.1

# Unexpected symlink
$ ls -l /opt/greenplum-db-5.27.0 | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep greenplum-db
lrwxrwxrwx root root greenplum-db-5.27.1 -> /opt/greenplum-db-5.27.1
```

### Greenplum 6 Current Behavior

#### Install

```console
$ yum install -y -d0 ./greenplum-db-6.8.0-rhel7-x86_64.rpm

$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /usr/local/greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.0
```

#### Upgrade

```console
$ yum install -y -d0 ./greenplum-db-6.8.0-rhel7-x86_64.rpm

# Same behavior between 'upgrade' and 'install'
# Unexpected error to stdout
$ yum upgrade -y -d0 ./greenplum-db-6.8.1-rhel7-x86_64.rpm
ln: failed to create symbolic link '/usr/local/greenplum-db': File exists

# Missing expected symlink
$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
drwxr-xr-x root root greenplum-db-6.8.1
```

#### Downgrade

```console
$ yum install -y -d0 ./greenplum-db-6.8.0-rhel7-x86_64.rpm

# Unexpected error to stdout
$ yum upgrade -y -d0 ./greenplum-db-6.8.1-rhel7-x86_64.rpm
ln: failed to create symbolic link '/usr/local/greenplum-db': File exists

$ yum downgrade -y -d0 ./greenplum-db-6.8.0-rhel7-x86_64.rpm

$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /usr/local/greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.0
```

#### Relocated Install

```console
$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt
error: Failed dependencies:

# Method to install dependencies if not met
$ yum deplist ./greenplum-db-6.8.0-rhel7-x86_64.rpm | awk '/provider:/ {print $2}' | sort -u | xargs yum -y -d0 install

$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt

$ ls -l /opt/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /opt/greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.0
```

#### Relocated Upgrade

```console
$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt
error: Failed dependencies:

# Method to install dependencies if not met
$ yum deplist ./greenplum-db-6.8.0-rhel7-x86_64.rpm | awk '/provider:/ {print $2}' | sort -u | xargs yum -y -d0 install

$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt

# Unexpected error to stdout
$ rpm -U ./greenplum-db-6.8.1-rhel7-x86_64.rpm --prefix=/opt
ln: failed to create symbolic link '/opt/greenplum-db': File exists

# Missing expected symlink
$ ls -l /opt | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
drwxr-xr-x root root greenplum-db-6.8.1
```

#### Relocated Downgrade

```console
$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt
error: Failed dependencies:

# Method to install dependencies if not met
$ yum deplist ./greenplum-db-6.8.0-rhel7-x86_64.rpm | awk '/provider:/ {print $2}' | sort -u | xargs yum -y -d0 install

$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt
# Unexpected error to stdout

$ rpm -U ./greenplum-db-6.8.1-rhel7-x86_64.rpm --prefix=/opt
ln: failed to create symbolic link '/opt/greenplum-db': File exists

$ rpm -U --oldpackage ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt

$ ls -l /opt/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /opt/greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.0
```

#### Dual Install (same package major version)

```console
$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm
error: Failed dependencies:

# Method to install dependencies if not met
$ yum deplist ./greenplum-db-6.8.0-rhel7-x86_64.rpm | awk '/provider:/ {print $2}' | sort -u | xargs yum -y -d0 install

$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm

# Unexpected error to stdout
$ rpm -i ./greenplum-db-6.8.1-rhel7-x86_64.rpm
ln: failed to create symbolic link '/usr/local/greenplum-db': File exists

# Symlink unexpectedly points to first installation
$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /usr/local/greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.1
```

#### Relocated Dual Install (same package major version)

```console
$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt
error: Failed dependencies:

# Method to install dependencies if not met
$ yum deplist ./greenplum-db-6.8.0-rhel7-x86_64.rpm | awk '/provider:/ {print $2}' | sort -u | xargs yum -y -d0 install

$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt
# Unexpected error to stdout

$ rpm -i ./greenplum-db-6.8.1-rhel7-x86_64.rpm --prefix=/opt
ln: failed to create symbolic link '/opt/greenplum-db': File exists

# Symlink unexpectedly points to first installation
$ ls -l /opt/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /opt/greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.1
```

### Expected Behavior for All Major Versions

#### Install

```console
$ yum install -y -d0 ./greenplum-db-6.8.0-rhel7-x86_64.rpm

$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /usr/local/greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.0
```

#### Upgrade

```console
$ yum install -y -d0 ./greenplum-db-6.8.0-rhel7-x86_64.rpm

$ yum upgrade -y -d0 ./greenplum-db-6.8.1-rhel7-x86_64.rpm

$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /usr/local/greenplum-db-6.8.1
drwxr-xr-x root root greenplum-db-6.8.1
# The 6.8.0 installation directory may still exist
```

#### Downgrade

```console
$ yum install -y -d0 ./greenplum-db-6.8.0-rhel7-x86_64.rpm

$ yum upgrade -y -d0 ./greenplum-db-6.8.1-rhel7-x86_64.rpm

$ yum downgrade -y -d0 ./greenplum-db-6.8.0-rhel7-x86_64.rpm

$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /usr/local/greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.0
# The 6.8.1 installation directory may still exist
```

#### Relocated Install

```console
# First, install dependencies as needed
$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt

$ ls -l /opt/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /opt/greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.0
```

#### Relocated Upgrade

```console
# First, install dependencies as needed

$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt

$ rpm -U ./greenplum-db-6.8.1-rhel7-x86_64.rpm --prefix=/opt

$ ls -l /opt | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /usr/local/greenplum-db-6.8.1
drwxr-xr-x root root greenplum-db-6.8.1
# The 6.8.0 installation directory may still exist
```

#### Relocated Downgrade

```console
# First, install dependencies as needed

$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt

$ rpm -U ./greenplum-db-6.8.1-rhel7-x86_64.rpm --prefix=/opt

$ rpm -U --oldpackage ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt

$ ls -l /opt/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /opt/greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.0
# The 6.8.1 installation directory may still exist
```

#### Dual Install (same package major version)

```console
# First, install dependencies as needed

$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm

$ rpm -i ./greenplum-db-6.8.1-rhel7-x86_64.rpm

$ ls -l /usr/local/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /usr/local/greenplum-db-6.8.1
drwxr-xr-x root root greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.1
```

#### Relocated Dual Install (same package major version)

```console
# First, install dependencies as needed

$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt

$ rpm -i ./greenplum-db-6.8.0-rhel7-x86_64.rpm --prefix=/opt

$ rpm -i ./greenplum-db-6.8.1-rhel7-x86_64.rpm --prefix=/opt

$ ls -l /opt/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /opt/greenplum-db-6.8.1
drwxr-xr-x root root greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-6.8.1
```

#### Dual Install (different package major version)

```console
$ yum install -y -d0 ./greenplum-db-5.27.0-rhel7-x86_64.rpm
$ yum install -y -d0 ./greenplum-db-6.8.0-rhel7-x86_64.rpm

$ ls -l /opt/ | awk {'print $1" "$3" "$4" "$9" "$10" "$11'} | grep green
lrwxrwxrwx root root greenplum-db -> /opt/greenplum-db-6.8.0
drwxr-xr-x root root greenplum-db-5.27.0
drwxr-xr-x root root greenplum-db-6.8.0
```
