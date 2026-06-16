CONFIG := config/.pre-commit-config.yaml

.PHONY: install lint test

install:
	pre-commit install --config $(CONFIG)
	pre-commit install --hook-type commit-msg --config $(CONFIG)

lint:
	pre-commit run --all-files --config $(CONFIG)

test:
	bash scripts/test.sh
