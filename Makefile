# mac-triage developer tasks. Run `make help` for the list.
SHELL := /bin/bash
VERSION := $(shell cat VERSION)
# Run bats under /bin/bash (3.2), the shell the tool runs with on every Mac.
BATS := PATH="/bin:/usr/bin:$$PATH" bats
SCRIPTS := src/macscan $(wildcard src/core/*.sh src/core/lib/*.sh src/modules/*.sh) src/installer/install.sh $(wildcard scripts/*.sh)

.PHONY: help build install lint test test-unit test-smoke test-detection test-build check release clean

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-16s %s\n", $$1, $$2}'

build: ## Build dist/install-mac-triage.sh, the tarball and SHA256SUMS
	@scripts/build.sh

install: build ## Build, then install on this Mac (asks for your password)
	sudo bash dist/install-mac-triage.sh

lint: ## shellcheck and static checks
	shellcheck -s bash $(SCRIPTS)
	$(BATS) tests/static

test-unit: ## Unit tests for the shared libraries and the CLI
	$(BATS) tests/unit

test-smoke: ## Run modules against a fixture home as the current user
	$(BATS) tests/smoke

test-detection: ## Detection tests with synthetic fixtures
	$(BATS) tests/detection

test-build: ## Build the installer and verify it
	$(BATS) tests/build

test: lint test-unit test-smoke test-detection test-build ## Everything (run before every build or release)

check: test build ## Full gate: all tests, then build

release: ## Tag vVERSION after all checks pass (clean tree, CHANGELOG entry, tests, build)
	@test -z "$$(git status --porcelain)" || { echo "Working tree is not clean."; exit 1; }
	@grep -q '^## \[$(VERSION)\]' CHANGELOG.md || { echo "CHANGELOG.md has no entry for $(VERSION)."; exit 1; }
	@! git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null || { echo "Tag v$(VERSION) already exists."; exit 1; }
	$(MAKE) check
	git tag -a "v$(VERSION)" -m "mac-triage $(VERSION)"
	@echo "Tagged v$(VERSION). Publish with: git push origin main --tags"

clean: ## Remove build output
	rm -rf dist
