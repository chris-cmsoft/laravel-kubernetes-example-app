# VERSION defines the project version for the bundle.
# Update this value when you upgrade the version of your project.
# To re-generate a bundle for another specific version without changing the standard setup, you can:
# - use the VERSION as arg of the bundle target (e.g make bundle VERSION=0.0.2)
# - use environment variables to overwrite this value (e.g export VERSION=0.0.2)
VERSION ?= v0.0.1

# Image URL to use all building/pushing image targets
REGISTRY ?= registry.gitlab.com/laravel-in-kubernetes/laravel-app

all: build push

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

build:
	docker build . -t ${REGISTRY}/cli:${VERSION} --target cli
	docker build . -t ${REGISTRY}/fpm_server:${VERSION} --target fpm_server
	docker build . -t ${REGISTRY}/web_server:${VERSION} --target web_server
	docker build . -t ${REGISTRY}/cron:${VERSION} --target cron
	docker build . -t ${REGISTRY}/tests:${VERSION} --target tests

push:
	docker push ${REGISTRY}/cli:${VERSION}
	docker push ${REGISTRY}/fpm_server:${VERSION}
	docker push ${REGISTRY}/web_server:${VERSION}
	docker push ${REGISTRY}/cron:${VERSION}
	docker push ${REGISTRY}/tests:${VERSION}

test-unit:
	php artisan test --testsuite=Unit

test-unit-in-docker:
	docker run -i --rm --name test-unit --entrypoint php ${REGISTRY}/tests:${VERSION} artisan test --testsuite Unit
