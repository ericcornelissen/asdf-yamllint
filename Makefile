# SPDX-License-Identifier: MIT-0

CONTAINER_ENGINE?=docker

TMP_DIR:=.tmp
BIN_DIR:=bin

ASDF:=$(TMP_DIR)/.asdf
DEV_IMG:=$(TMP_DIR)/.dev-img

ALL_SCRIPTS:=./$(BIN_DIR)/* ./lib/*

SHELLCHECK_OPTS:='--enable=avoid-nullary-conditions --enable=deprecate-which --enable=quote-safe-variables --enable=require-variable-braces'

.PHONY: default
default: help

.PHONY: clean
clean: ## Clean the repository
	@git clean -fx \
		$(TMP_DIR)

.PHONY: dev-env dev-img
dev-env: dev-img ## Run an ephemeral development environment container
	@$(CONTAINER_ENGINE) run \
		-it \
		--rm \
		--workdir "/asdf-yamllint" \
		--mount "type=bind,source=$(shell pwd),target=/asdf-yamllint" \
		--name "asdf-yamllint-dev" \
		asdf-yamllint-dev-img

dev-img: $(DEV_IMG) ## Build a development environment image

.PHONY: format format-check
format: $(ASDF) ## Format the source code
	@shfmt --simplify --write $(ALL_SCRIPTS)

format-check: $(ASDF) ## Check the source code formatting
	@shfmt --simplify --diff $(ALL_SCRIPTS)

.PHONY: help
help: ## Show this help message
	@printf "Usage: make <command>\n\n"
	@printf "Commands:\n"
	@awk -F ':(.*)## ' '/^[a-zA-Z0-9%\\\/_.-]+:(.*)##/ { \
		printf "  \033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)

.PHONY: lint lint-ci lint-container lint-sh
lint: lint-ci lint-container lint-sh ## Run lint-*

lint-ci: $(ASDF) ## Lint CI workflow files
	@SHELLCHECK_OPTS=$(SHELLCHECK_OPTS) \
		actionlint

lint-container: $(ASDF) ## Lint the Containerfile
	@hadolint Containerfile.dev

lint-sh: $(ASDF) ## Lint .sh files
	@SHELLCHECK_OPTS=$(SHELLCHECK_OPTS) \
		shellcheck \
		$(ALL_SCRIPTS)

.PHONY: release
release: ## Release a new version
ifneq "$(shell git branch --show-current)" "main"
	@echo 'refusing to release, not on main branch'
	@echo 'first run: "git switch main"'
else ifeq "$v" ""
	@echo 'usage: "make release v=1.0.1"'
else
	@git tag "v$v"
	@git push origin "v$v"
endif

.PHONY: test-download test-help test-install test-installation test-latest-stable test-list-all
test-download: | $(TMP_DIR) ## Test the download script
ifeq "$(version)" ""
	@echo 'usage: "make test-download version=1.29.0"'
else
	@rm -rf \
		"${TMP_DIR}/download/checksum.txt" \
		"${TMP_DIR}/download/yamllint-$(version).tar.gz" \
		"${TMP_DIR}/download/yamllint-$(version)"
	@( \
		ASDF_DOWNLOAD_PATH="${TMP_DIR}/download" \
		ASDF_INSTALL_VERSION="$(version)" \
		./$(BIN_DIR)/download \
	)
endif

test-help: ## Test the help scripts
	@echo "OVERVIEW"
	@./$(BIN_DIR)/help.overview
	@echo
	@echo "DEPENDENCIES"
	@./$(BIN_DIR)/help.deps
	@echo
	@echo "LINKS"
	@./$(BIN_DIR)/help.links

test-install: | $(TMP_DIR) ## Test the install script
ifeq "$(version)" ""
	@echo 'usage: "make test-install version=1.29.0"'
else
	@rm -rf \
		"${TMP_DIR}/install/checksum.txt" \
		"${TMP_DIR}/install/yamllint-$(version).tar.gz" \
		"${TMP_DIR}/install/bin/yamllint" \
		"${TMP_DIR}/install/yamllint-$(version)"
	@( \
		ASDF_INSTALL_PATH="${TMP_DIR}/install" \
		ASDF_INSTALL_VERSION="$(version)" \
		./$(BIN_DIR)/install \
	)
endif

test-installation: ## Test the installation
	@echo 'INSTALLED VERSION:'
	@echo '------------------'
	@$(TMP_DIR)/install/bin/yamllint --version
	@echo
	@echo 'HELP TEXT:'
	@echo '----------'
	@$(TMP_DIR)/install/bin/yamllint --help

test-latest-stable: ## Test the latest-stable scripts
	@./$(BIN_DIR)/latest-stable

test-list-all: ## Test the list-all script
	@./$(BIN_DIR)/list-all

.PHONY: verify
verify: format-check lint ## Verify project is in a good state

$(TMP_DIR):
	@mkdir $(TMP_DIR)
$(ASDF): .tool-versions | $(TMP_DIR)
	@asdf install || true
	@touch $(ASDF)
$(DEV_IMG): .tool-versions Containerfile.dev | $(TMP_DIR)
	@$(CONTAINER_ENGINE) build \
		--tag asdf-yamllint-dev-img \
		--file Containerfile.dev \
		.
	@touch $(DEV_IMG)
