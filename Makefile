## ======================================================================
##                     greenplum-database-release - Makefile
## ======================================================================
## Variables
## ======================================================================

# set the concourse target default to dev
ifndef CONCOURSE
override CONCOURSE  = dev
endif

# set the gp-release default branch to current branch
ifndef BRANCH
override BRANCH = $(shell git rev-parse --abbrev-ref HEAD)
endif

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

	sed -e 's|tag_filter: *|## tag_filter: |g' concourse/pipelines/gpdb_opensource_release.yml > concourse/pipelines/${PIPELINE_NAME}.yml

	$(FLY_CMD) --target=${CONCOURSE} \
    set-pipeline \
    --pipeline=${PIPELINE_NAME} \
    --config=concourse/pipelines/${PIPELINE_NAME}.yml \
    --load-vars-from=${HOME}/workspace/gp-continuous-integration/secrets/gpdb-oss-release.dev.yml  \
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
	$(FLY_CMD) --target=prod \
    set-pipeline \
    --pipeline=greenplum-database-release \
    --config=concourse/pipelines/gpdb_opensource_release.yml \
    --load-vars-from=${HOME}/workspace/gp-continuous-integration/secrets/gpdb-oss-release.prod.yml  \
    --var=pipeline-name=greenplum-database-release \
    --var=greenplum-database-release-git-branch=master \
    --var=greenplum-database-release-git-remote=https://github.com/greenplum-db/greenplum-database-release.git \
    ${FLY_OPTION_NON-INTERACTIVE}

	@echo using the following command to unpause the pipeline:
	@echo "\t$(FLY_CMD) -t prod unpause-pipeline --pipeline 6X-release"
