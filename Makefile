.DEFAULT_GOAL := help

.PHONY: help install lint test

help:
	@echo "Available targets:"
	@echo "  install  - install pre-commit hooks (run once after cloning)"
	@echo "  lint     - run all pre-commit hooks against every file"
	@echo "  test     - run setup.sh inside an Ubuntu 24.04 Docker container"

install:
	pre-commit install
	pre-commit install --hook-type commit-msg

lint:
	pre-commit run --all-files

test:
	bash tests/test.sh
