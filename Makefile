# Copyright (C) 2019-Present VMware, and affiliates Inc. All rights reserved.
# This program and the accompanying materials are made available under the
# terms of the under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain a
# copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
## ======================================================================
##                     greenplum-database-release - Makefile
## ======================================================================
## Variables
## ======================================================================

# set the concourse target default to dev
CONCOURSE ?= releng

# set the gp-release default branch to current branch
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
WORKSPACE ?= ${HOME}/workspace

PIPELINE_NAME              = greenplum-database-release-${BRANCH}-${USER}
FLY_CMD                    = fly
FLY_OPTION_NON-INTERACTIVE =

DEV_INTEGRATION_PIPELINE_NAME = dev-gpdb6-integration-testing-${BRANCH}-${USER}


## ----------------------------------------------------------------------
## List explicit rules
## ----------------------------------------------------------------------

.PHONY: list
list:
	@sh -c "$(MAKE) -p no_targets__ 2>/dev/null | \
	awk -F':' '/^[a-zA-Z0-9][^\$$#\/\\t=]*:([^=]|$$)/ {split(\$$1,A,/ /);for(i in A)print A[i]}' | \
	grep -v Makefile | \
	grep -v '%' | \
	grep -v '__\$$' | \
	sort"

## ----------------------------------------------------------------------
## Set Development Pipeline
## ----------------------------------------------------------------------

.PHONY: set-dev
set-dev:

	sed -e 's|tag_filter: *|## tag_filter: |g' ci/concourse/pipelines/gpdb_opensource_release.yml > ci/concourse/pipelines/${PIPELINE_NAME}.yml

	$(FLY_CMD) --target=${CONCOURSE} \
    set-pipeline \
    --check-creds \
    --pipeline=${PIPELINE_NAME} \
    --config=ci/concourse/pipelines/${PIPELINE_NAME}.yml \
    --load-vars-from=${WORKSPACE}/gp-continuous-integration/secrets/gpdb-oss-release.dev.yml \
    --load-vars-from=${WORKSPACE}/gp-continuous-integration/secrets/ppa-debian-release-secrets-dev.yml \
    --load-vars-from=ci/concourse/vars/greenplum-database-release.dev.yml \
    --var=greenplum-database-release-git-branch=${BRANCH} \
    --var=greenplum-database-release-git-remote=https://github.com/greenplum-db/greenplum-database-release.git \
    --var=pipeline-name=${PIPELINE_NAME} \
    ${FLY_OPTION_NON-INTERACTIVE}

	@echo using the following command to unpause the pipeline:
	@echo "\t$(FLY_CMD) -t ${CONCOURSE} unpause-pipeline --pipeline ${PIPELINE_NAME}"

## ----------------------------------------------------------------------
## Destroy Development Pipeline
## ----------------------------------------------------------------------

.PHONY: destroy-dev
destroy-dev:
	$(FLY_CMD) --target=${CONCOURSE} \
    destroy-pipeline \
    --pipeline=${PIPELINE_NAME} \
    ${FLY_OPTION_NON-INTERACTIVE}

## ----------------------------------------------------------------------
## Set Production Pipeline
## ----------------------------------------------------------------------

.PHONY: set-prod
set-prod:
	sed -e 's|commitish: release_artifacts/commitish|## commitish: release_artifacts/commitish|g' ci/concourse/pipelines/gpdb_opensource_release.yml > ci/concourse/pipelines/gpdb_opensource_release_prod.yml

	$(FLY_CMD) --target=prod \
    set-pipeline \
    --check-creds \
    --pipeline=greenplum-database-release \
    --config=ci/concourse/pipelines/gpdb_opensource_release_prod.yml \
    --load-vars-from=${WORKSPACE}/gp-continuous-integration/secrets/gpdb-oss-release.prod.yml \
    --load-vars-from=${WORKSPACE}/gp-continuous-integration/secrets/ppa-debian-release-secrets.yml \
    --load-vars-from=ci/concourse/vars/greenplum-database-release.prod.yml \
    --var=pipeline-name=greenplum-database-release \
    --var=greenplum-database-release-git-branch=main \
    --var=greenplum-database-release-git-remote=https://github.com/greenplum-db/greenplum-database-release.git \
    ${FLY_OPTION_NON-INTERACTIVE}

	@echo using the following command to unpause the pipeline:
	@echo "\t$(FLY_CMD) -t prod unpause-pipeline --pipeline greenplum-database-release"

## ----------------------------------------------------------------------
## Package Testing Pipelines
## ----------------------------------------------------------------------
.PHONY: set-gpdb-package-testing-prod
set-gpdb-package-testing-prod:
	$(FLY_CMD) --target=$(CONCOURSE) \
	set-pipeline \
	--check-creds \
	--pipeline=gpdb-package-testing \
	--config=ci/concourse/pipelines/gpdb-package-testing.yml \
	--load-vars-from=ci/concourse/vars/gpdb-package-testing.prod.yml \
	--load-vars-from=${WORKSPACE}/gp-continuous-integration/secrets/gpdb-package-testing.prod.yml \
	$(FLY_OPTION_NON-INTERACTIVE)

.PHONY: set-gpdb-package-testing-dev
set-gpdb-package-testing-dev:
	$(FLY_CMD) --target=$(CONCOURSE) \
	set-pipeline \
	--check-creds \
	--pipeline=gpdb-package-testing-$(BRANCH)-${USER} \
	--config=ci/concourse/pipelines/gpdb-package-testing.yml \
	--load-vars-from=ci/concourse/vars/gpdb-package-testing.prod.yml \
	--load-vars-from=ci/concourse/vars/gpdb-package-testing.dev.yml \
	--load-vars-from=${WORKSPACE}/gp-continuous-integration/secrets/gpdb-package-testing.prod.yml \
	--load-vars-from=${WORKSPACE}/gp-continuous-integration/secrets/gpdb-package-testing.dev.yml \
	--var=greenplum-database-release-git-branch=${BRANCH} \
	$(FLY_OPTION_NON-INTERACTIVE)

.PHONY: set-gpdb6-package-testing-prod
set-gpdb6-package-testing-prod:
	$(FLY_CMD) --target=$(CONCOURSE) \
	set-pipeline \
	--check-creds \
	--pipeline=gpdb6-package-testing \
	--config=ci/gpdb6/concourse/pipelines/gpdb6-package-testing.yml \
	--load-vars-from=ci/gpdb6/concourse/vars/gpdb6-package-testing.prod.yml \
	--load-vars-from=${WORKSPACE}/gp-continuous-integration/secrets/gpdb6-package-testing.prod.yml \
	--var=pipeline-name=gpdb6-integration-testing \
	$(FLY_OPTION_NON-INTERACTIVE)

.PHONY: set-gpdb6-package-testing-dev
set-gpdb6-package-testing-dev:
	$(FLY_CMD) --target=$(CONCOURSE) \
	set-pipeline \
	--check-creds \
	--pipeline=gpdb6-package-testing-$(BRANCH)-${USER} \
	--config=ci/gpdb6/concourse/pipelines/gpdb6-package-testing.yml \
	--load-vars-from=ci/gpdb6/concourse/vars/gpdb6-package-testing.prod.yml \
	--load-vars-from=ci/gpdb6/concourse/vars/gpdb6-package-testing.dev.yml \
	--load-vars-from=${WORKSPACE}/gp-continuous-integration/secrets/gpdb6-package-testing.prod.yml \
	--load-vars-from=${WORKSPACE}/gp-continuous-integration/secrets/gpdb6-package-testing.dev.yml \
	--var=greenplum-database-release-git-branch=${BRANCH} \
	--var=pipeline-name=${DEV_INTEGRATION_PIPELINE_NAME}
	$(FLY_OPTION_NON-INTERACTIVE)

## ----------------------------------------------------------------------
## Lint targets
## ----------------------------------------------------------------------
.PHONY: check
check:
	$(MAKE) lint

.PHONY: lint
lint: shfmt
	docker run --rm \
        -e RUN_LOCAL=true \
        -e VALIDATE_MD=true \
        -e VALIDATE_BASH=true \
        -e VALIDATE_YAML=true \
        -v ${PWD}:/tmp/lint \
        github/super-linter:v3

.PHONY: shfmt
shfmt:
	docker run --rm -v ${PWD}:/code mvdan/shfmt:v2.6.4 -d /code

## ----------------------------------------------------------------------
## Local packaging targets
## ----------------------------------------------------------------------

GPDB_MAJOR_VERSION = $(shell echo "${GPDB_VERSION}" | cut -d '.' -f1)

.PHONY: local-build-gpdb-rpm
local-build-gpdb-rpm:
	$(MAKE) local-build-gpdb$(GPDB_MAJOR_VERSION)-rpm

.PHONY: local-build-gpdb6-rpm local-build-gpdb7-rpm
local-build-gpdb6-rpm local-build-gpdb7-rpm:
	bin/create_gpdb6_rpm_package.bash

.PHONY: local-build-gpdb5-rpm local-build-gpdb4-rpm
local-build-gpdb5-rpm local-build-gpdb4-rpm:
	bin/create_gpdb5_rpm_package.bash

.PHONY:
local-build-gpdb-deb:
	$(MAKE) local-build-gpdb$(GPDB_MAJOR_VERSION)-deb

.PHONY: local-build-gpdb5-deb
local-build-gpdb5-deb:
	bin/create_gpdb5_deb_package.bash

.PHONY: local-build-gpdb6-deb local-build-gpdb7-deb
local-build-gpdb6-deb local-build-gpdb7-deb:
	bin/create_gpdb6_deb_package.bash
