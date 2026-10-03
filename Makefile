SWIFT_BIN := $(shell xcrun --find swift)
TOOLCHAIN := $(patsubst %/usr/bin/swift,%,$(SWIFT_BIN))
TESTING_PLUGINS := $(TOOLCHAIN)/usr/lib/swift/host/plugins/testing

# CLT without Xcode does not pass the Swift Testing macro plugin path to the compiler.
TEST_FLAGS := $(if $(wildcard $(TESTING_PLUGINS)),-Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGINS))

.PHONY: build test clean

build:
	swift build

test:
	swift test $(TEST_FLAGS)

clean:
	swift package clean
	rm -rf build
