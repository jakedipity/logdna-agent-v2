REPO := logdna-agent-v2

# The image repo and tag can be modified e.g.
# `make -f Makefile.docker build IMAGE=docker.io/rust:1.42.0`
IMAGE_REPO ?= docker.io/rust
IMAGE_TAG ?= 1.42
IMAGE ?= $(IMAGE_REPO):$(IMAGE_TAG)
IMAGE := $(IMAGE)

DOCKER := docker
DOCKER_RUN := docker run --rm -w /build -v $(shell pwd):/build:Z $(IMAGE)
DOCKER_PRIVATE_IMAGE := us.gcr.io/logdna-k8s/logdna-agent-v2
DOCKER_PUBLIC_IMAGE := docker.io/logdna/logdna-agent
DOCKER_IBM_IMAGE := icr.io/ext/logdna-agent

VCS_REF := $(shell git rev-parse --short HEAD)
VCS_URL := https://github.com/logdna/$(REPO)
BUILD_TIMESTAMP := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
BUILD_VERSION := $(shell sed -nE "s/^version = \"(.+)\"\$$/\1/p" bin/Cargo.toml)
BUILD_TAG := $(VCS_REF)

MAJOR_VERSION := $(shell echo $(BUILD_VERSION) | cut -f1 -d'.')
MINOR_VERSION := $(shell echo $(BUILD_VERSION) | cut -f1-2 -d'.')
PATCH_VERSION := $(shell echo $(BUILD_VERSION) | cut -f1 -d'-')

# This is to reliably maintain permissions in a cross compatible manner
# (tested on Linux and Mac). The docker container needs the correct
# permissions to build artifcats, but also needs to give ownership of build
# artifacts back to the host machine.
CHOWN := chown -R $(shell id -u):$(shell id -g) .

ifeq ($(ALL), 1)
	CLEAN_TAG := *
else
	CLEAN_TAG := $(BUILD_TAG)
endif

CLEAN_DOCKER_IMAGES = if [[ ! -z "docker images -q $(1)" ]]; then docker images -q $(1) | xargs docker rmi -f; fi

PULL ?= 1
ifeq ($(PULL), 1)
	PULL_OPTS := --pull
else
	PULL_OPTS :=
endif

CARGO := cargo
RUSTUP := rustup

ifeq ($(RELEASE), 1)
	CARGO_COMPILE_OPTS := --release
else
	CARGO_COMPILE_OPTS :=
endif

.PHONY:build
build: ## Build the agent. Set RELEASE=1 to build a release image - defaults to 0
	$(CARGO) build $(CARGO_COMPILE_OPTS)

.PHONY:clean
clean: ## Clean all artifacts from the build process
	$(CARGO) clean

.PHONY:test
test: ## Check rust syntax, docker syntax, rust warnings, outdated dependencies, security vulnerabilities, and unit tests
	$(CARGO) fmt -- --check
	$(CARGO) clippy --all-targets $(CARGO_COMPILE_OPTS) -- -D warnings
	$(CARGO) +nightly udeps --all-targets $(CARGO_COMPILE_OPTS)
	$(CARGO) audit
	$(CARGO) test $(CARGO_COMPILE_OPTS)

.PHONY:test-deps
test-deps: ## Install dependencies needed for the test target
	$(RUSTUP) update
	$(RUSTUP) toolchain install nightly
	$(RUSTUP) component add clippy
	$(RUSTUP) component add rustfmt
	$(CARGO) +nightly install cargo-udeps
	$(CARGO) install cargo-audit

.PHONY:docker-build
docker-build: ## (Runs in a docker container) Build the agent. Set RELEASE=1 to build a release image - defaults to 0
	$(DOCKER_RUN) /bin/sh -c "make build RELEASE=$(RELEASE) && $(CHOWN)"

.PHONY:docker-test
docker-test: ## (Runs in a docker container) Installs the necessary dependencies and then checks rust syntax, docker syntax, rust warnings, outdated dependencies, security vulnerabilities, and unit tests
	$(DOCKER_RUN) /bin/sh -c "make test && $(CHOWN)"

.PHONY:docker-clean
docker-clean: ## (Runs in a docker container) Clean all artifacts from the build process
	$(DOCKER_RUN) /bin/sh -c "make clean && $(CHOWN)"

.PHONY:docker-clean-images
docker-clean-images: ## Cleans the intermediate and final agent images left over from the build-image target
	@# Clean any agent images, left over from the multi-stage build
	$(call CLEAN_DOCKER_IMAGES,$(REPO):$(CLEAN_TAG))

.PHONY:docker-build-image
docker-build-image: ## Build a docker image as specified in the Dockerfile
	$(DOCKER) build . -t $(REPO):$(BUILD_TAG) \
		$(PULL_OPTS) --no-cache=true --rm \
		--build-arg BUILD_IMAGE=$(IMAGE) \
		--build-arg BUILD_TIMESTAMP=$(BUILD_TIMESTAMP) \
		--build-arg BUILD_VERSION=$(BUILD_VERSION) \
		--build-arg REPO=$(REPO) \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg VCS_URL=$(VCS_URL)
	$(DOCKER) tag $(REPO):$(BUILD_TAG) $(REPO):$(BUILD_VERSION)

.PHONY:docker-publish-private
docker-publish-private: ## Publish a build version of the docker image to our private registry
	for version in $(BUILD_TAG) $(BUILD_VERSION); do \
		$(DOCKER) tag $(REPO):$(BUILD_TAG) $(DOCKER_PRIVATE_IMAGE):$${version}; \
		$(DOCKER) push $(DOCKER_PRIVATE_IMAGE):$${version}; \
	done;

.PHONY:docker-publish-public
docker-publish-public: ## Publish SemVer compliant releases to our public registries
	@# TODO: Have a boolean that prevents this unless forced or run by Jenkins (which can force it)
	for image in $(DOCKER_PUBLIC_IMAGE) $(DOCKER_IBM_IMAGE); do \
		for version in $(MAJOR_VERSION) $(MINOR_VERSION) $(PATCH_VERSION) $(BUILD_VERSION) latest; do \
			$(DOCKER) tag $(REPO):$(BUILD_TAG) $${image}:$${version}; \
			$(DOCKER) push $${image}:$${version}; \
		done; \
	done;

.PHONY:help
help: ## Prints out a helpful description of each possible target
	@awk 'BEGIN {FS = ":.*?## "}; /^.+: .*?## / && !/awk/ {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
