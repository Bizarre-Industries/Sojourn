# Sojourn — dev DX
# See docs/IMPLEMENTATION_PLAN.md for the build/test contract.

SWIFT_FORMAT ?= $(shell command -v swift-format 2>/dev/null || xcrun --find swift-format 2>/dev/null)

.PHONY: help bootstrap build test lint leaks generate xcodebuild clean format \
        ci-local act-ci act-build actionlint pin-actions verify-pins zizmor

help:
	@echo 'Sojourn — make targets:'
	@echo '  bootstrap  install xcodegen, swiftlint, swift-format, gitleaks, act, actionlint via brew'
	@echo '  build      swift build (library target)'
	@echo '  test       swift test (unit tests via Swift Testing)'
	@echo '  generate   xcodegen generate (regenerate Sojourn.xcodeproj)'
	@echo '  xcodebuild xcodebuild test on the generated project'
	@echo '  leaks      gitleaks dir --config=.gitleaks.toml --redact'
	@echo '  lint       swiftlint (advisory)'
	@echo '  format     swift-format in place'
	@echo '  ci-local   local release gate: workflows, leaks, pins, zizmor, expiry, advisory Swift lint'
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

xcodebuild:
	@set -e; \
	team="$${DEVELOPMENT_TEAM:-}"; \
	if [ -z "$$team" ]; then \
		team="$$(awk -F= '/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=/{gsub(/[[:space:]]/, "", $$2); print $$2; exit}' Sojourn/Config/Local.xcconfig 2>/dev/null || true)"; \
	fi; \
	if ! printf '%s\n' "$$team" | grep -Eq '^[A-Z0-9]{10}$$'; then \
		echo 'make xcodebuild runs SojournUITests and requires real Apple Development signing.'; \
		echo 'Set Sojourn/Config/Local.xcconfig with DEVELOPMENT_TEAM = <10-char Team ID>'; \
		echo 'or pass DEVELOPMENT_TEAM=<10-char Team ID> to make.'; \
		echo 'Unsigned/ad-hoc UI-test loader failures are not release evidence.'; \
		echo 'For unsigned unit-only validation use:'; \
		echo "  xcodebuild test -project Sojourn.xcodeproj -scheme Sojourn -destination 'platform=macOS' -only-testing:SojournTests"; \
		exit 2; \
	fi; \
	if [ -z "$${CODE_SIGN_IDENTITY:-}" ]; then \
		echo 'make xcodebuild runs SojournUITests and must not use Sign to Run Locally.'; \
		echo 'Pass CODE_SIGN_IDENTITY="Apple Development" after local certificates are installed.'; \
		echo 'Unsigned/ad-hoc UI-test loader failures are not release evidence.'; \
		echo 'For unsigned unit-only validation use:'; \
		echo "  xcodebuild test -project Sojourn.xcodeproj -scheme Sojourn -destination 'platform=macOS' -only-testing:SojournTests"; \
		exit 2; \
	fi; \
	$(MAKE) generate; \
	xcodebuild -scheme Sojourn -destination 'platform=macOS' test \
		DEVELOPMENT_TEAM="$$team" \
		CODE_SIGN_IDENTITY="$${CODE_SIGN_IDENTITY}"

leaks:
	gitleaks dir --config=.gitleaks.toml --redact -v

lint:
	-swiftlint

format:
	$(SWIFT_FORMAT) format -i -r Sojourn SojournTests SojournUITests

clean:
	swift package clean
	rm -rf .build build DerivedData

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

# Release gate: required checks first, advisory lint/format last.
ci-local: actionlint leaks verify-pins zizmor
	-swiftlint lint --strict --reporter emoji
	-$(SWIFT_FORMAT) lint --recursive Sojourn SojournTests SojournUITests \
		--parallel --configuration .swift-format
	@command -v python3 >/dev/null && python3 .github/scripts/check-expiry.py --validate

# Pin every action in .github/ to a commit SHA + # vX.Y.Z comment
pin-actions:
	@command -v pinact >/dev/null 2>&1 || { echo "install: brew install pinact"; exit 1; }
	pinact run --update
	@echo "review: git diff .github/"

# CI-style verification — fail if anything is unpinned
verify-pins:
	@command -v pinact >/dev/null 2>&1 || { echo "install: brew install pinact"; exit 1; }
	pinact run --check

# Workflow security lint
zizmor:
	@command -v zizmor >/dev/null 2>&1 || { echo "install: brew install zizmor"; exit 1; }
	zizmor .github/
