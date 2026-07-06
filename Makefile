.DEFAULT_GOAL := help

.PHONY: help install lint test protect-branch

BRANCH ?= main
CHECKS ?= pre-commit / Pre-commit

help:
	@echo "Available targets:"
	@echo "  install        - install pre-commit hooks (run once after cloning)"
	@echo "  lint           - run all pre-commit hooks against every file"
	@echo "  test           - run setup.sh inside an Ubuntu 24.04 Docker container"
	@echo "  protect-branch - configure GitHub repo settings (auto-merge, branch protection) via gh CLI"
	@echo "                   args: BRANCH=main CHECKS=\"<required check names>\" (defaults: main, pre-commit)"

install:
	pre-commit install
	pre-commit install --hook-type commit-msg

lint:
	pre-commit run --all-files

test:
	bash tests/test.sh

protect-branch:
	./scripts/protect-branch.sh "$(BRANCH)" "$(CHECKS)"
