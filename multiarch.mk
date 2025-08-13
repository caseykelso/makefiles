# Makefile for building and publishing cross-platform artifacts
# Supports Linux, macOS, Windows with proper architecture detection

# Detect operating system
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
    OS := linux
endif
ifeq ($(UNAME_S),Darwin)
    OS := macos
endif
ifeq ($(UNAME_S),MINGW32_NT*)
    OS := windows
endif
ifeq ($(UNAME_S),MINGW64_NT*)
    OS := windows
endif
ifeq ($(OS),)
    OS := unknown
endif

# Detect architecture
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),x86_64)
    ARCH := x86_64
endif
ifeq ($(UNAME_M),amd64)
    ARCH := x86_64
endif
ifeq ($(UNAME_M),arm64)
    ARCH := arm64
endif
ifeq ($(UNAME_M),aarch64)
    ARCH := arm64
endif
ifeq ($(UNAME_M),armv7l)
    ARCH := arm
endif
ifeq ($(ARCH),)
    ARCH := unknown
endif

# Git information
GIT_TAG := $(shell git describe --tags --exact-match 2>/dev/null)
GIT_HASH := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Use tag if available, otherwise use hash
ifeq ($(GIT_TAG),)
    VERSION := $(GIT_HASH)
    VERSION_TYPE := hash
else
    VERSION := $(GIT_TAG)
    VERSION_TYPE := tag
endif

# Build timestamp
BUILD_TIME := $(shell date +%Y%m%d_%H%M%S)

# Artifact naming
ARTIFACT.NAME := $(PROJECT_NAME)-$(VERSION)-$(OS)-$(ARCH)
FULL_ARTIFACT.NAME := $(ARTIFACT.NAME)-$(BUILD_TIME)

BINARY_EXT :=
ARCHIVE_EXT := .tar.gz
ARCHIVE_CMD := tar -czf

# Display build information
.PHONY: info
info:
	@echo "Build Information:"
	@echo "  Project: $(PROJECT_NAME)"
	@echo "  OS: $(OS)"
	@echo "  Architecture: $(ARCH)"
	@echo "  Version: $(VERSION) ($(VERSION_TYPE))"
	@echo "  Git Hash: $(GIT_HASH)"
	@echo "  Git Branch: $(GIT_BRANCH)"
	@echo "  Build Time: $(BUILD_TIME)"
	@echo "  Artifact Name: $(ARTIFACT.NAME)"

distribute: .FORCE
	rm -rf $(DIST.DIR) && mkdir -p $(DIST.DIR)
	cp -r $(INSTALLED.HOST.DIR)/bin $(DIST.DIR)/bin
	cp -r $(INSTALLED.HOST.DIR)/lib $(DIST.DIR)/lib
	cp -r $(INSTALLED.HOST.DIR)/include $(DIST.DIR)/include

package: .FORCE
	mkdir -p $(PACKAGE.DIR)
	cd $(PACKAGE.DIR) && tar czvf $(ARTIFACT.NAME).tar.gz -C $(DIST.DIR) .  && md5sum $(ARTIFACT.NAME).tar.gz > $(ARTIFACT.NAME).tar.gz.md5

upload: .FORCE
ifndef S3.BUCKET
$(error S3.BUCKET must be defined.)
endif
	PATH=$(HOME)/.local/bin:$(PATH) $(AWS.BIN) s3 cp $(PACKAGE.DIR)/$(ARTIFACT.NAME).tar.gz s3://$(S3.BUCKET) --acl public-read --no-progress
	PATH=$(HOME)/.local/bin:$(PATH) $(AWS.BIN) s3 cp $(PACKAGE.DIR)/$(ARTIFACT.NAME).tar.gz.md5 s3://$(S3.BUCKET) --acl public-read --no-progress
	@echo https://$(S3.BUCKET).s3.amazonaws.com/$(PACKAGE.LINUX.ARCHIVE)
	@echo https://$(S3.BUCKET).s3.amazonaws.com/$(PACKAGE.LINUX.ARCHIVE).md5


# Cross-compilation targets (requires appropriate toolchains)
.PHONY: build-linux-x86_64
build-linux-x86_64:
	$(MAKE) OS=linux ARCH=x86_64 CMAKE_ARGS="-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=x86_64" build

.PHONY: build-linux-arm64
build-linux-arm64:
	$(MAKE) OS=linux ARCH=arm64 CMAKE_ARGS="-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=aarch64" build

.PHONY: build-windows-x86_64
build-windows-x86_64:
	$(MAKE) OS=windows ARCH=x86_64 CMAKE_ARGS="-DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=x86_64" build

.PHONY: build-macos-x86_64
build-macos-x86_64:
	$(MAKE) OS=macos ARCH=x86_64 CMAKE_ARGS="-DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_SYSTEM_PROCESSOR=x86_64" build

.PHONY: build-macos-arm64
build-macos-arm64:
	$(MAKE) OS=macos ARCH=arm64 CMAKE_ARGS="-DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_SYSTEM_PROCESSOR=arm64" build

# Build all common targets
.PHONY: build-all
build-all: build-linux-x86_64 build-linux-arm64 build-windows-x86_64 build-macos-x86_64 build-macos-arm64

# Package all targets
.PHONY: package-all
package-all:
	$(MAKE) OS=linux ARCH=x86_64 package
	$(MAKE) OS=linux ARCH=arm64 package
	$(MAKE) OS=windows ARCH=x86_64 package
	$(MAKE) OS=macos ARCH=x86_64 package
	$(MAKE) OS=macos ARCH=arm64 package

# Show all available targets
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all          - Build and package for current platform"
	@echo "  info         - Show build information"
	@echo "  build        - Build the project"
	@echo "  package      - Create distributable archive"
	@echo "  upload-github - Upload to GitHub Releases (requires GITHUB_TOKEN)"
	@echo "  build-all    - Cross-compile for all targets"
	@echo "  package-all  - Package all cross-compiled targets"
	@echo "  clean        - Remove build artifacts"
	@echo ""
	@echo "Cross-compilation targets:"
	@echo "  build-linux-x86_64   build-linux-arm64"
	@echo "  build-windows-x86_64 build-macos-x86_64 build-macos-arm64"

