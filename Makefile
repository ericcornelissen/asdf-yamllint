TMP_DIR:=.tmp
BIN_DIR:=bin

default: help

clean: ## Clean the repository
	@git clean -fx \
		$(TMP_DIR)

format: ## Format the source code
	@shfmt --simplify --write \
		./$(BIN_DIR)/download \
		./$(BIN_DIR)/install \
		./$(BIN_DIR)/list-all \
		./lib/common.sh

format-check: ## Check the source code formatting
	@shfmt --diff \
		./$(BIN_DIR)/download \
		./$(BIN_DIR)/install \
		./$(BIN_DIR)/list-all \
		./lib/common.sh

help: ## Show this help message
	@printf "Usage: make <command>\n\n"
	@printf "Commands:\n"
	@awk -F ':(.*)## ' '/^[a-zA-Z0-9%\\\/_.-]+:(.*)##/ { \
		printf "  \033[36m%-30s\033[0m %s\n", $$1, $$NF \
	}' $(MAKEFILE_LIST)

lint: lint-ci lint-sh

lint-ci: ## Lint CI workflow files
	@actionlint

lint-sh: ## Lint .sh files
	@shellcheck \
		./$(BIN_DIR)/download \
		./$(BIN_DIR)/install \
		./$(BIN_DIR)/list-all \
		./lib/common.sh

release: ## Release a new version
ifeq "$v" ""
	@echo 'usage: "make release v=1.0.1"'
else
	@git tag "v$v"
	@git push origin "v$v"
endif

ifeq "$(version)" ""
test-download:
	@echo 'usage: "make test-download version=1.29.0"'
else
test-download: | $(TMP_DIR) ## Test run the bin/download script
	@rm -rf \
		"${TMP_DIR}/download/checksum.txt" \
		"${TMP_DIR}/download/yamllint-$(version).tar.gz" \
		"${TMP_DIR}/download/yamllint-$(version)"
	@( \
		ASDF_DOWNLOAD_PATH="${TMP_DIR}/download" \
		ASDF_INSTALL_VERSION="$(version)" \
		./bin/download \
	)
endif

ifeq "$(version)" ""
test-install:
	@echo 'usage: "make test-install version=1.29.0"'
else
test-install: | $(TMP_DIR) ## Test run the bin/install script
	@rm -rf \
		"${TMP_DIR}/install/checksum.txt" \
		"${TMP_DIR}/install/yamllint-$(version).tar.gz" \
		"${TMP_DIR}/install/bin/yamllint" \
		"${TMP_DIR}/install/yamllint-$(version)"
	@( \
		ASDF_INSTALL_PATH="${TMP_DIR}/install" \
		ASDF_INSTALL_VERSION="$(version)" \
		./bin/install \
	)
endif

test-installation: ## Test that the bin/install script worked
	@$(TMP_DIR)/install/bin/yamllint --help

test-list-all: ## Test run the bin/list-all script
	@./$(BIN_DIR)/list-all

.PHONY: clean default format format-check help lint lint-ci lint-sh release test-download test-install test-installation test-list-all

$(TMP_DIR):
	@mkdir $(TMP_DIR)
