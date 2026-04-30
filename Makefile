# Sojourn — dev DX
# See docs/IMPLEMENTATION_PLAN.md for the build/test contract.

.PHONY: help bootstrap build test lint leaks generate xcodebuild clean format \
        ci-local act-ci act-build actionlint

help:
	@echo 'Sojourn — make targets:'
	@echo '  bootstrap  install xcodegen, swiftlint, swift-format, gitleaks, act, actionlint via brew'
	@echo '  build      swift build (library target)'
	@echo '  test       swift test (unit tests via Swift Testing)'
	@echo '  generate   xcodegen generate (regenerate Sojourn.xcodeproj)'
	@echo '  xcodebuild xcodebuild test on the generated project'
	@echo '  leaks      gitleaks dir --config=.gitleaks.toml'
	@echo '  lint       swiftlint (advisory)'
	@echo '  format     swift-format in place'
	@echo '  ci-local   run quality+security checks locally (mirrors ci.yml)'
	@echo '  act-ci     run ci.yml ubuntu jobs locally via act (Docker required)'
	@echo '  act-build  run build.yml jobs locally — macOS jobs unsupported by act, use xcodebuild'
	@echo '  actionlint lint .github/workflows/*.yml'
	@echo '  clean      swift package clean + remove build artefacts'

bootstrap:
	@brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
	@brew list swiftlint >/dev/null 2>&1 || brew install swiftlint
	@brew list swift-format >/dev/null 2>&1 || brew install swift-format
	@brew list gitleaks >/dev/null 2>&1 || brew install gitleaks
	@brew list act >/dev/null 2>&1 || brew install act
	@brew list actionlint >/dev/null 2>&1 || brew install actionlint

build:
	swift build

test:
	swift test

generate:
	bash scripts/regenerate-project.sh

xcodebuild: generate
	xcodebuild -scheme Sojourn -destination 'platform=macOS' test

leaks:
	gitleaks dir --config=.gitleaks.toml

lint:
	-swiftlint

format:
	swift-format format -i -r Sojourn SojournTests SojournUITests

clean:
	swift package clean
	rm -rf .build build DerivedData

# Mirror what ci.yml runs on every push/PR: gitleaks scan + lint +
# format-check. Run before every commit. Catches anything the
# pre-commit gate misses.
ci-local: actionlint leaks
	-swiftlint lint --strict --reporter emoji
	-swift-format lint --recursive Sojourn SojournTests SojournUITests \
		--parallel --configuration .swift-format

# Lint workflow YAML before push. ci.yml job-level `if: hashFiles(...)`
# silently failed pre-runner with 0s duration — actionlint catches that.
actionlint:
	actionlint .github/workflows/*.yml

# Run ci.yml ubuntu jobs (gitleaks scan) inside a local Docker
# container via nektos/act. Docker daemon must be running.
# macOS jobs (lint, format-check) cannot be virtualized by act —
# `make ci-local` covers those natively.
act-ci:
	@command -v act >/dev/null 2>&1 || { echo "act not installed. run: make bootstrap"; exit 1; }
	@docker info >/dev/null 2>&1 || { echo "Docker daemon not running"; exit 1; }
	act push --job gitleaks --workflows .github/workflows/ci.yml

# Smoke-run build.yml's swift-test job on push event. macOS-only swift
# toolchain inside the container is unreliable; xcodebuild target above
# is the canonical local path. This target is for completeness only.
act-build:
	@command -v act >/dev/null 2>&1 || { echo "act not installed. run: make bootstrap"; exit 1; }
	@echo 'NOTE: build.yml runs on macos-15 — act cannot virtualize macOS.'
	@echo '      Use `make test` (swift test) and `make xcodebuild` instead.'
	@echo '      To still attempt: act push --job swift-test --workflows .github/workflows/build.yml -P macos-15=-self-hosted'
