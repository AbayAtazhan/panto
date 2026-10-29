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

format: ## format Swift sources (swift format, Xcode toolchain)
	swift format --in-place --recursive Sources Tests

lint: ## lint Swift sources
	swift format lint --recursive Sources Tests

clean: ## remove build products
	rm -rf .build build
