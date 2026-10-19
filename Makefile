SWIFT_BIN := $(shell xcrun --find swift)
TOOLCHAIN := $(patsubst %/usr/bin/swift,%,$(SWIFT_BIN))
TESTING_PLUGINS := $(TOOLCHAIN)/usr/lib/swift/host/plugins/testing

# CLT without Xcode does not pass the Swift Testing macro plugin path to the compiler.
TEST_FLAGS := $(if $(wildcard $(TESTING_PLUGINS)),-Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS))

.PHONY: build test coverage app run install clean

build:
	swift build

test:
	swift test $(TEST_FLAGS)

coverage:
	swift test --enable-code-coverage $(TEST_FLAGS)
	BIN=$$(swift build --show-bin-path) && \
	CODECOV=$$(dirname "$$(swift test --show-codecov-path)") && \
	xcrun llvm-cov report "$$BIN/GlossCoreTests.xctest/Contents/MacOS/GlossCoreTests" \
		-instr-profile="$$CODECOV/default.profdata" "$(CURDIR)/Sources/GlossCore"

app:
	scripts/build-app.sh

run: app
	open build/Gloss.app

install: app
	rm -rf /Applications/Gloss.app
	ditto build/Gloss.app /Applications/Gloss.app

clean:
	swift package clean
	rm -rf build
