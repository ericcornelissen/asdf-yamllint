TMP_DIR:=.tmp
BIN_DIR:=bin

ASDF:=$(TMP_DIR)/.asdf
DEV_IMG:=$(TMP_DIR)/.dev-img

ALL_SCRIPTS:=./$(BIN_DIR)/* ./lib/*

default: help

clean: ## Clean the repository
	@git clean -fx \
		$(TMP_DIR)

dev-env: $(DEV_IMG) ## Run an ephemeral dev env with Docker
	@docker run \
		-it \
		--rm \
		--workdir "/asdf-yamllint" \
		--mount "type=bind,source=$(shell pwd),target=/asdf-yamllint" \
		--name "asdf-yamllint-dev" \
		asdf-yamllint-dev-img

format: $(ASDF) ## Format the source code
	@shfmt --simplify --write $(ALL_SCRIPTS)

format-check: $(ASDF) ## Check the source code formatting
	@shfmt --diff $(ALL_SCRIPTS)

help: ## Show this help message
	@printf "Usage: make <command>\n\n"
	@printf "Commands:\n"
	@awk -F ':(.*)## ' '/^[a-zA-Z0-9%\\\/_.-]+:(.*)##/ { \
		printf "  \033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)

lint: lint-ci lint-sh ## Run lint-*

lint-ci: $(ASDF) ## Lint CI workflow files
	@actionlint

lint-sh: $(ASDF) ## Lint .sh files
	@shellcheck $(ALL_SCRIPTS)

release: ## Release a new version
ifeq "$v" ""
	@echo 'usage: "make release v=1.0.1"'
else
	@git tag "v$v"
	@git push origin "v$v"
endif

test-download: | $(TMP_DIR) ## Test run the download script
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

test-install: | $(TMP_DIR) ## Test run the install script
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
	@$(TMP_DIR)/install/bin/yamllint --help

test-list-all: ## Test run the list-all script
	@./$(BIN_DIR)/list-all

verify: format-check lint ## Verify project is in a good state

.PHONY: \
	clean default dev-env help release verify \
	format format-check \
	lint lint-ci lint-sh \
	test-download test-install test-installation test-list-all

$(TMP_DIR):
	@mkdir $(TMP_DIR)
$(ASDF): .tool-versions | $(TMP_DIR)
	@asdf install
	@touch $(ASDF)
$(DEV_IMG): Dockerfile | $(TMP_DIR)
	@docker build \
		--tag asdf-yamllint-dev-img \
		.
	@touch $(DEV_IMG)
