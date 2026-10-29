SHELL := /bin/bash

.PHONY: build app dmg run test selftest clean

build: ## compile the release binary (Command Line Tools are enough)
	swift build -c release

app: ## build Panto.app with icon and signature
	./scripts/make_app.sh

dmg: app ## build a drag-to-Applications DMG
	./scripts/make_dmg.sh

run: app ## build and open the app
	open build/Panto.app

test: ## unit tests (needs Xcode for XCTest)
	swift test

selftest: build ## synthetic recording -> zoom -> frames, no permissions needed
	./.build/release/Panto --selftest

clean: ## remove build products
	rm -rf .build build
