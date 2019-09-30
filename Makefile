# Copyright (C) 2019-Present Pivotal Software, Inc. All rights reserved.
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

PIPELINE_NAME              = greenplum-database-release-${BRANCH}-${USER}
FLY_CMD                    = fly
FLY_OPTION_NON-INTERACTIVE =

.PHONY: set-dev set-pipeline-dev destroy-dev destroy-pipeline-dev set-prod set-pipeline-prod

## ----------------------------------------------------------------------
## List explicit rules
## ----------------------------------------------------------------------

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

set-dev: set-pipeline-dev

set-pipeline-dev:

	sed -e 's|tag_filter: *|## tag_filter: |g' ci/concourse/pipelines/gpdb_opensource_release.yml > ci/concourse/pipelines/${PIPELINE_NAME}.yml

	$(FLY_CMD) --target=${CONCOURSE} \
    set-pipeline \
    --pipeline=${PIPELINE_NAME} \
    --config=ci/concourse/pipelines/${PIPELINE_NAME}.yml \
    --load-vars-from=${HOME}/workspace/gp-continuous-integration/secrets/gpdb-oss-release.dev.yml \
    --load-vars-from=${HOME}/workspace/gp-continuous-integration/secrets/ppa-debian-release-secrets-dev.yml \
    --var=greenplum-database-release-git-branch=${BRANCH} \
    --var=greenplum-database-release-git-remote=https://github.com/greenplum-db/greenplum-database-release.git \
    --var=pipeline-name=${PIPELINE_NAME} \
    ${FLY_OPTION_NON-INTERACTIVE}

	@echo using the following command to unpause the pipeline:
	@echo "\t$(FLY_CMD) -t ${CONCOURSE} unpause-pipeline --pipeline ${PIPELINE_NAME}"

## ----------------------------------------------------------------------
## Destroy Development Pipeline
## ----------------------------------------------------------------------

destroy-dev: destroy-pipeline-dev

destroy-pipeline-dev:
	$(FLY_CMD) --target=${CONCOURSE} \
    destroy-pipeline \
    --pipeline=${PIPELINE_NAME} \
    ${FLY_OPTION_NON-INTERACTIVE}

## ----------------------------------------------------------------------
## Set Production Pipeline
## ----------------------------------------------------------------------

set-prod: set-pipeline-prod

set-pipeline-prod:
	sed -e 's|commitish: release_artifacts/commitish|## commitish: release_artifacts/commitish|g' ci/concourse/pipelines/gpdb_opensource_release.yml > ci/concourse/pipelines/gpdb_opensource_release_prod.yml

	$(FLY_CMD) --target=prod \
    set-pipeline \
    --pipeline=greenplum-database-release \
    --config=ci/concourse/pipelines/gpdb_opensource_release_prod.yml \
    --load-vars-from=${HOME}/workspace/gp-continuous-integration/secrets/gpdb-oss-release.prod.yml \
    --load-vars-from=${HOME}/workspace/gp-continuous-integration/secrets/ppa-debian-release-secrets.yml \
    --var=pipeline-name=greenplum-database-release \
    --var=greenplum-database-release-git-branch=master \
    --var=greenplum-database-release-git-remote=https://github.com/greenplum-db/greenplum-database-release.git \
    ${FLY_OPTION_NON-INTERACTIVE}

	@echo using the following command to unpause the pipeline:
	@echo "\t$(FLY_CMD) -t prod unpause-pipeline --pipeline greenplum-database-release"
