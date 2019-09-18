# Greenplum Database Packaging

This directory is an experiment in building Greenplum Database packages from source.

## Setting Concourse CI pipeline

```sh
fly -t releng set-pipeline \
    -p "dev:greenplum-database-packaging:${USER}" \
    -c ~/workspace/greenplum-database-release/packaging/ci/concourse/pipeline.yml \
    -l ~/workspace/gp-continuous-integration/secrets/greenplum-database-packaging.dev.yml
```

## libgpopt3

This is a Debian package containing all the shared libraries provided by gporca. It is a Debian lint for a package to contain libraries and not have the package name match one of the libraries.
