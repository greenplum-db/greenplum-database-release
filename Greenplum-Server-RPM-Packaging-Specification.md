# Greenplum Server RPM Packaging Specification

Description of the expected behavior as it relates to RPM packaging for the Greenplum Server component

# Supported Features

1. All of the basic functionality offered by the RPM specifications

2. The package installation root is relocatable.

  Some users have IT and platform requirements regarding where software is installed. The default installation directory is `/usr/local/` but it can be changed during installation by using `rpm --prefix=[dir]`. Note: When using **rpm** for package installation, automatic dependency resolution does not occur.

3. Packages of different major versions can be installed at the same time.

  Data migration for a Major version upgrade require both major versions to be installed. Additionally, some users may wish to simultanously run multiple versions of Greenplum concurrently or otherwise with the ability to easily choose a different version of Greenplum. The package names are suffixed with a major version number, which prevents conflict and allows both `greenplum-db-5` and `greenplum-db-6` to be installed simultaneously.

4. Packages of different minor or patch version numbers can be installed at the same time using `rpm --install`

  Some users may wish to simultanously run multiple versions of Greenplum concurrently or otherwise with the ability to easily choose a different version of Greenplum. The package installation prefix is unique for every package, `%{prefix}/greenplum-db-[major version]-[version]`, and the package does not attempt to create a `/usr/local/greenplum-db` symlink. This choices prevent file conflicts between packages and allows a user to `rpm --install` to install many versions of the package. Note: When using **rpm** for package installation, automatic dependency resolution does not occur.

# Detailed Package Behavior

_Packaging Layer_
- The `Name` metadata field of the RPM package shall be `greenplum-db-[x]`, such that `[x]` is the Greenplum Major version number
- The filename of the resulting file shall be `greenplum-db-[x.y.z]-[PLATFORM]-x86_64.rpm`, such that `[x.y.z]` is the Greenplum Server version string and `[PLATFORM]` is one of `RHEL6`, `RHEL7`, `sles11`, `sles12`
- The package shall make any installed `greenplum-db` package, of the same Major version, obsolete upon installation. Examples:
  - If `greenplum-db` version `5.0.0` is installed, then a user installs `greenplum-db-6` version `6.0.0`, both packages shall remain installed
  - If `greenplum-db` version `6.0.0` is installed, then a user installs `greenplum-db-6` version `6.0.0`, only `greenplum-db-6` version `6.0.0` shall remain installed
  - If `greenplum-db` version `6.0.0` is installed, then a user installs `greenplum-db-6` version `6.0.1`, only `greenplum-db-6` version `6.0.1` shall remain installed
- The package shall by default be installed at `/usr/local/greenplum-db-[package version]` (Note: this is not the same as `/usr/local/[package-name]-[package-version]`)
- The package shall be named based on [Greenplum Filename Specifications](https://github.com/pivotal/gp-releng/blob/master/docs/Greenplum-Filename-Specifications.md)
- The package shall be [relocatable](http://ftp.rpm.org/api/4.4.2.2/relocatable.html)
- The package shall not create nor modify any `/usr/local/greenplum-db` symbolic link
- When performing an upgrade, downgrade, or uninstall of the RPM package, any changes to the installed `${installation prefix}/greenplum-db-[package-version]/greenplum_path.sh` file shall not be removed. (Note: This does not include transferring changes; It is only for saving changes)

_Greenplum Path Layer_
- `greenplum-path.sh` shall be installed to `${installation prefix}/greenplum-db-[package-version]/greenplum_path.sh`
- `${GPHOME}` shall by default be set to `%{installation prefix}/greenplum-db-[version]`
  - If the installation prefix for a package is changed from the default by a user, then `%{installation prefix` shall be updated during installation to reflect the user's preference
- `${LD_LIBRARY_PATH}` shall be set to `${GPHOME}/lib:${PYTHONHOME}/lib:${LD_LIBRARY_PATH-}`
- `${PYTHONHOME}` shall be set to `${GPHOME}/ext/python`-
  - Note: the existing `test -x` shall be removed. Refer to [this slack conversation](https://pivotal.slack.com/archives/C4B0FBK0T/p1576523800033300)) for an explanation.
- `${PYTHONPATH}` shall be set to `${GPHOME}/lib/python`
- `${PATH}` shall be set to `${GPHOME}/bin:${PYTHONHOME}/bin:${PATH}`
- If the file `${GPHOME}/etc/openssl.cnf` exists then `${OPENSSL_CONF}` shall be set to `${GPHOME}/etc/openssl.cnf`
- [A portable bash shebang shall be set](https://stackoverflow.com/questions/10376206/what-is-the-preferred-bash-shebang)
- The `greenplum_path.sh` file shall pass [ShellCheck](https://github.com/koalaman/shellcheck)

_Runtime Linking Layer_
- Any of the `elf` formatted files within the package at `${GPHOME}/bin`, that relied on `${LD_LIBRARY_PATH}` being set for runtime linking, shall now rely on `${RUNPATH}` being set to `${ORIGIN}/../lib`
  - Exception: The following exceptions are golang binaries that shall not have `RUNPATH` set:
    - `bin/gpkafka` (Greenplum 6, Greenplum 5)
    - `bin/gpbackup_s3_plugin` (Greenplum 5)
    - `bin/gprestore` (Greenplum 5)
    - `bin/gpbackup` (Greenplum 5)
    - `bin/gpbackup_helper` (Greenplum 5)
- Any of the "elf" formatted files within the package at `${GPHOME}/ext/python/bin/`, that relied on `${LD_LIBRARY_PATH}` being set for runtime linking, shall now rely on `RUNPATH` being set to `${ORIGIN}/../lib:$ORIGIN/../../../lib`
- Any of the "elf" formatted files within the package at `${GPHOME}/lib/`, that relied on `${LD_LIBRARY_PATH}` being set for runtime linking, shall now rely on `RUNPATH` being set to `${ORIGIN}/../lib`
  - Exception (Greenplum 6): `${GPHOME}/lib/postgresql/quicklz_compressor.so` shall have its `RUNPATH` set to `${ORIGIN}/../../lib`
  - Exception (Greenplum 6, Greenplum 5): `${GPHOME}/lib/python/pygresql/_pg.so` shall have its `RUNPATH` set to `${ORIGIN}/../../../lib`
- (Greenplum 5): The `elf` formatted file `${GPHOME}/ext/python/lib/python2.7/lib-dynload/_hashlib.so`, that relied on `${LD_LIBRARY_PATH}` being set for runtime linking, shall now rely on `RUNPATH` being set to `${ORIGIN}/../../../../../lib`
- In all situations where `RUNPATH` is involved, if it is already set it shall be updated, if it is not set it shall be added

# Usage

Documenation of how a user is expected to to interact with the Greenplum Server package. Each package state transition should end with a running cluster with a psql prompt (with the exception of uninstallation or currently unsupported state transitions).

## Installation

### How to perform an installation

1. Follow the Pivotal Greenplum documentation for ["Configuring Your System"](https://gpdb.docs.pivotal.io/6-1/install_guide/prep_os.html) and ["Creating the Data Storage Areas"](https://gpdb.docs.pivotal.io/6-1/install_guide/create_data_dirs.html)

2. Download the Greenplum Server binary RPM package installer from https://network.pivotal.io

3. Transfer the RPM package to all hosts being used for the Greenplum cluster

4. On every host, as a **root** user, install the RPM package and any necessary dependencies

   ```sh
   sudo yum install ./greenplum-db-[version]-[platform]-[arch].rpm
   ```

5. Follow the Pivotal Greenplum documentation for  ["Initializing a Greenplum Database System"](https://gpdb.docs.pivotal.io/6-4/install_guide/init_gpdb.html)

6. Download any optional Greenplum extensions from https://network.pivotal.io

7. Follow the Pivotal Greenplum documentation for ["Installing Optional Extensions"](https://gpdb.docs.pivotal.io/6-1/install_guide/data_sci_pkgs.html)

8. On the host designated as the **master** host, as the **gpadmin** user, ensure the necessary environment variables are set

   ```sh
   source /usr/local/greenplum-db-[version]/greenplum_path.sh
   export MASTER_DATA_DIRECTORY=[data directory designated during cluster initialization]
   ```

9. On the host designated as the **master** host, as the **gpadmin** user, start a client connection to the running Greenplum cluster

   ```sh
   psql -d postgres
   ```

### The state of the environment after installation

   ```sh
   $ ls -l /usr/local/ | grep greenplum
   drwxr-xr-x  10 root root 127 Dec 24 06:12 greenplum-db-6.1.0
   ```

   ```sh
   $ yum info greenplum-db-6
   ...
   Installed Packages
   Name        : greenplum-db
   Arch        : x86_64
   Version     : 6.1.0
   Release     : 1.el7
   Size        : 498 M
   Repo        : installed
   From repo   : /greenplum-db-6.1.0-rhel7-x86_64
   Summary     : Greenplum-DB
   URL         : https://network.pivotal.io/products/pivotal-gpdb/
   License     : Pivotal Software EULA
   Description : Greenplum Database
   ```

## Upgrade

### Major version upgrade

#### How to perform a Major version upgrade

1. Perform the installation steps above for Greenplum 5

2. Download the Greenplum 6 Server binary RPM package installer from https://network.pivotal.io

3. Transfer the RPM package to all hosts being used for the Greenplum cluster

4. On every host, as a **root** user, install the Greenplum 6 RPM package and any necessary dependencies

   ```sh
   sudo yum install ./greenplum-db-[version]-[platform]-[arch].rpm
   ```

5. On the host designated as the **master** host, as the **gpadmin** user, set the necessary environment variables for the Greenplum 5 cluster

   ```sh
   source /usr/local/greenplum-db-5-[full version]/greenplum_path.sh
   ```

6. On the host designated as the **master** host, as the **gpadmin** user, set the necessary environment variables for any intialized Greenplum 5 database

   ```sh
   export MASTER_DATA_DIRECTORY=[data directory designated during cluster initialization]
   ```

7. Ensure the Greenplum 5 cluster being upgraded is stopped

   ```sh
   gpstop -a
   ```

8. Follow the documented steps for [Migrating Data from Greenplum 4.3 or 5](https://gpdb.docs.pivotal.io/6-1/install_guide/migrate.html)

9. Uninstall the Greenplum 5 package

  ```sh
  # If the Greenplum 5 version is <= [XXX]
  yum remove greenplum-db
  # If the Greenplum 5 version is > [XXX]
  yum remove greenplum-db-5
  ```

#### The state of the environment after a Major version upgrade

   ```sh
   $ ls -l /usr/local/ | grep greenplum
   drwxr-xr-x  10 root root 127 Dec 24 06:12 greenplum-db-6.1.0
   ```

   ```sh
   $ yum info greenplum-db-6
   ...
   Installed Packages
   Name        : greenplum-db
   Arch        : x86_64
   Version     : 6.1.0
   Release     : 1.el7
   Size        : 498 M
   Repo        : installed
   From repo   : /greenplum-db-6.1.0-rhel7-x86_64
   Summary     : Greenplum-DB
   URL         : https://network.pivotal.io/products/pivotal-gpdb/
   License     : Pivotal Software EULA
   Description : Greenplum Database
   ```

### Minor/Maintenance upgrade

#### How to perform a Minor/Maintenance version upgrade

1. Download the new Greenplum Server binary RPM package installer from https://network.pivotal.io

2. Transfer the RPM package to all hosts being used for the Greenplum cluster

3. On the host designated as the **master** host, as the **gpadmin** user, set the necessary environment variables for the **existing** Greenplum Server installation

   ```sh
   source /usr/local/greenplum-db-[major version]-[full version]/greenplum_path.sh
   ```

4. On the host designated as the **master** host, as the **gpadmin** user, set the necessary environment variables for the location of the **existing**, initalized cluster that is being upgraded

   ```sh
   export MASTER_DATA_DIRECTORY=[data directory designated during cluster initialization]
   ```

5. Ensure the **existing** Greenplum cluster being upgraded is stopped

   ```sh
   gpstop -a
   ```

6. On every host, as a **root** user, install the RPM package and any necessary dependencies

   ```sh
   sudo yum install ./greenplum-db-[version]-[platform]-[arch].rpm
   ```

7. On the host designated as the **master** host, as the **gpadmin** user, ensure any necessary modifications to the `greenplum_path.sh` configuration file from the **existing** Greenplum Server installation are transfered to the configuration file of the **upgraded** Greenplum server installation

   ```sh
   vim /usr/local/greenplum-db-[existing version]/greenplum_path.sh.rpmsave
   vim /usr/local/greenplum-db-[upgraded version]/greenplum_path.sh
   ```

8. On the host designated as the **master** host, as the **gpadmin** user, set the necessary environment variables for the **upgraded** Greenplum Server installation

   ```sh
   source /usr/local/greenplum-db-[major version]-[full version]/greenplum_path.sh
   ```

9. Start any **upgraded** Greenplum cluster database

   ```sh
   gpstart
   ```

#### The state of the environment after a Minor/Maintenance version upgrade

   ```sh
   $ ls -l /usr/local/ | grep greenplum
   drwxr-xr-x  10 root root 127 Dec 24 06:12 greenplum-db-6.1.0
   ```

   ```sh
   $ yum info greenplum-db-6
   ...
   Installed Packages
   Name        : greenplum-db
   Arch        : x86_64
   Version     : 6.1.0
   Release     : 1.el7
   Size        : 498 M
   Repo        : installed
   From repo   : /greenplum-db-6.1.0-rhel7-x86_64
   Summary     : Greenplum-DB
   URL         : https://network.pivotal.io/products/pivotal-gpdb/
   License     : Pivotal Software EULA
   Description : Greenplum Database
   ```

## Downgrade

### Major version downgrade

#### How to perform a Major version downgrade

Unknown

#### The state of the environment after a Major version downgrade

Unknown

### Minor/Maintenance downgrade

#### How to perform a Minor/Maintenance version downgrade

1. Perform the installation steps for a Greenplum cluster

2. Download the downgraded Greenplum Server binary RPM package installer from https://network.pivotal.io

3. Transfer the RPM package to all hosts being used for the Greenplum cluster

4. On the host designated as the **master** host, set the necessary environment variables as the **gpadmin** user for the **existing** Greenplum Server installation

   ```sh
   source /usr/local/greenplum-db-[major version]-[full version]/greenplum_path.sh
   ```

5. On the host designated as the **master** host, set the necessary environment variables as the **gpadmin** user for the location of the **existing**, initalized cluster that is being upgraded

   ```sh
   export MASTER_DATA_DIRECTORY=[data directory designated during cluster initialization]
   ```

6. Ensure the **existing** Greenplum cluster being upgraded is stopped

   ```sh
   gpstop -a
   ```

7. On every host, downgrade the RPM package and any necessary dependencies

   ```sh
   sudo yum downgrade ./greenplum-db-[version]-[platform]-[arch].rpm
   ```

8. Ensure any necessary modifications to the `greenplum_path.sh` configuration file from the **existing** Greenplum Server installation are transfered to the **downgraded** configuration file 

   ```sh
   vim -p /usr/local/greenplum-db-[existing version]/greenplum_path.sh.rpmsave /usr/local/greenplum-db-[downgraded version]/greenplum_path.sh
   ```

9. On the host designated as the **master** host, set the necessary environment variables as the **gpadmin** user for the **downgraded** Greenplum Server installation

   ```sh
   source /usr/local/greenplum-db-[major version]-[full version]/greenplum_path.sh
   ```

10. Start the downgraded Greenplum cluster

   ```sh
   gpstart
   ```

#### The state of the environment after a Minor/Maintenance version downgrade

   ```sh
   $ ls -l /usr/local/ | grep greenplum
   lrwxrwxrwx   1 root root  30 Dec 24 06:12 greenplum-db -> /etc/alternatives/greenplum-db
   drwxr-xr-x  10 root root 127 Dec 24 06:12 greenplum-db-6.1.0
   ```

   ```sh
   $ yum info greenplum-db-6
   ...
   Installed Packages
   Name        : greenplum-db
   Arch        : x86_64
   Version     : 6.1.0
   Release     : 1.el7
   Size        : 498 M
   Repo        : installed
   From repo   : /greenplum-db-6.1.0-rhel7-x86_64
   Summary     : Greenplum-DB
   URL         : https://network.pivotal.io/products/pivotal-gpdb/
   License     : Pivotal Software EULA
   Description : Greenplum Database
   ```

## Uninstallation

### How to perform an uninstallation

1. Perform the installation steps for a Greenplum cluster

2. On the host designated as the **master** host, set the necessary environment variables as the **gpadmin** user for the **existing** Greenplum Server installation

   ```sh
   source /usr/local/greenplum-db-[major version]-[full version]/greenplum_path.sh
   ```

3. On the host designated as the **master** host, set the necessary environment variables as the **gpadmin** user for the location of the **existing**, initalized cluster that is being upgraded

   ```sh
   export MASTER_DATA_DIRECTORY=[data directory designated during cluster initialization]
   ```

4. Ensure the **existing** Greenplum cluster being upgraded is stopped

   ```sh
   gpstop -a
   ```

5. On every host, uninstall the RPM package and any necessary dependencies

   ```sh
   # If the Greenplum 5 versions is <= [XXX]
   yum remove greenplum-db
   # If the Greenplum 5 version is > [XXX]
   yum remove greenplum-db-5
   ```

### The state of the environment after an uninstallation

   The installation directory may still exist if any files contained within were not managed by the RPM package installer or if the `greenplum_path.sh` configuration contained modifications from what was initially installed

   ```sh
   $ ls -l /usr/local/ | grep greenplum
   drwxr-xr-x  10 root root 127 Dec 24 06:12 greenplum-db-6.1.0
   ```

