# Sojourn — dev DX
# See docs/IMPLEMENTATION_PLAN.md for the build/test contract.

.PHONY: help bootstrap build test lint leaks generate xcodebuild clean format

help:
	@echo 'Sojourn — make targets:'
	@echo '  bootstrap  install xcodegen, swiftlint, swift-format, gitleaks via brew'
	@echo '  build      swift build (library target)'
	@echo '  test       swift test (unit tests via Swift Testing)'
	@echo '  generate   xcodegen generate (regenerate Sojourn.xcodeproj)'
	@echo '  xcodebuild xcodebuild test on the generated project'
	@echo '  leaks      gitleaks dir --config=.gitleaks.toml'
	@echo '  lint       swiftlint (advisory)'
	@echo '  format     swift-format in place'
	@echo '  clean      swift package clean + remove build artefacts'

bootstrap:
	@brew list xcodegen >/dev/null 2>&1 || brew install xcodegen
	@brew list swiftlint >/dev/null 2>&1 || brew install swiftlint
	@brew list swift-format >/dev/null 2>&1 || brew install swift-format
	@brew list gitleaks >/dev/null 2>&1 || brew install gitleaks

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
