
BACKEND?=docker
CONCURRENCY?=1
CI_ARGS?=
PACKAGES?=

# Abs path only. It gets copied in chroot in pre-seed stages
export LUET?=/usr/bin/luet
export ROOT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
DESTINATION?=$(ROOT_DIR)/build
COMPRESSION?=gzip
CLEAN?=false
export COMMON_TREE?=${ROOT_DIR}/multi-arch/packages
export TREE?=$(ROOT_DIR)/amd64/packages
REPO_CACHE?=quay.io/mocaccinocache/musl-universe-amd64-cache
export REPO_CACHE
BUILD_ARGS?=--pull --no-spinner --only-target-package --live-output
SUDO?=
VALIDATE_OPTIONS?=-s
ARCH?=amd64

ifneq ($(strip $(REPO_CACHE)),)
	BUILD_ARGS+=--image-repository $(REPO_CACHE)
endif

.PHONY: all
all: deps build

.PHONY: deps
deps:
	@echo "Installing luet"
	go get -u github.com/mudler/luet

.PHONY: clean
clean:
	$(SUDO) rm -rf build/ *.tar *.metadata.yaml

.PHONY: build
build: clean
	mkdir -p $(DESTINATION)
	$(SUDO) $(LUET) build $(BUILD_ARGS) --tree=$(COMMON_TREE) --tree=$(TREE) $(PACKAGES) --destination $(DESTINATION) --backend $(BACKEND) --concurrency $(CONCURRENCY) --compression $(COMPRESSION)

.PHONY: build-all
build-all: clean
	mkdir -p $(DESTINATION)
	$(SUDO) $(LUET) build $(BUILD_ARGS) --tree=$(COMMON_TREE) --tree=$(TREE) --full --destination $(DESTINATION) --backend $(BACKEND) --concurrency $(CONCURRENCY) --compression $(COMPRESSION)

.PHONY: rebuild
rebuild:
	$(SUDO) $(LUET) build $(BUILD_ARGS) --tree=$(COMMON_TREE) --tree=$(TREE) $(PACKAGES) --destination $(DESTINATION) --backend $(BACKEND) --concurrency $(CONCURRENCY) --compression $(COMPRESSION)

.PHONY: rebuild-all
rebuild-all:
	$(SUDO) $(LUET) build $(BUILD_ARGS) --tree=$(COMMON_TREE) --tree=$(TREE) --full --destination $(DESTINATION) --backend $(BACKEND) --concurrency $(CONCURRENCY) --compression $(COMPRESSION)

.PHONY: create-repo
create-repo:
	$(SUDO) $(LUET) create-repo --tree "$(TREE)" --tree "$(COMMON_TREE)" \
    --output $(DESTINATION) \
    --packages $(DESTINATION) \
    --name "mocaccino-musl-universe" \
    --descr "MocaccinoOS Musl Universe repository $(ARCH)" \
    --urls "http://localhost:8000" \
    --tree-compression gzip \
    --tree-filename tree.tar \
    --meta-compression gzip \
    --type http

.PHONY: serve-repo
serve-repo:
	LUET_NOLOCK=true $(LUET) serve-repo --port 8000 --dir $(DESTINATION)

auto-bump:
	TREE_DIR=$(ROOT_DIR) $(LUET) autobump-github

autobump: auto-bump

repository:
	mkdir -p $(ROOT_DIR)/repository

repository/luet:
	git clone -b master --single-branch https://github.com/Luet-lab/luet-repo $(ROOT_DIR)/repository/luet

repository/commons:
	git clone -b master --single-branch https://github.com/mocaccinoos/os-commons $(ROOT_DIR)/repository/commons

repository/micro:
	git clone -b master --single-branch https://github.com/mocaccinoos/mocaccino-micro $(ROOT_DIR)/repository/micro

repository/desktop:
	git clone -b master --single-branch https://github.com/mocaccinoos/desktop $(ROOT_DIR)/repository/desktop

repository/extra:
	git clone -b master --single-branch https://github.com/mocaccinoos/mocaccino-extra $(ROOT_DIR)/repository/extra

validate: repository repository/micro repository/luet repository/extra repository/commons repository/desktop
	$(LUET) tree validate --tree $(ROOT_DIR)/repository --tree $(TREE) --tree=$(COMMON_TREE) $(VALIDATE_OPTIONS)


