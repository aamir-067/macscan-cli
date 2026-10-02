# mac-triage developer tasks. Run `make help` for the list.
SHELL := /bin/bash
VERSION := $(shell cat VERSION)

.PHONY: help build clean install

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-14s %s\n", $$1, $$2}'

build: ## Build dist/install-mac-triage.sh, the tarball and SHA256SUMS
	@scripts/build.sh

install: build ## Build, then install on this Mac (asks for your password)
	sudo bash dist/install-mac-triage.sh

clean: ## Remove build output
	rm -rf dist
