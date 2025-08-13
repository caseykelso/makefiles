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
ARTIFACT_NAME := $(PROJECT_NAME)-$(VERSION)-$(OS)-$(ARCH)
FULL_ARTIFACT_NAME := $(ARTIFACT_NAME)-$(BUILD_TIME)

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
	@echo "  Artifact Name: $(ARTIFACT_NAME)"


# Package the artifact
.PHONY: package
package: build $(DIST_DIR)
	@echo "Packaging $(ARTIFACT_NAME)..."
	# Create staging directory
	mkdir -p $(DIST_DIR)/$(ARTIFACT_NAME)
	
	# Copy binary
	cp $(BUILD_DIR)/$(PROJECT_NAME)$(BINARY_EXT) $(DIST_DIR)/$(ARTIFACT_NAME)/
	
	# Copy additional files
	cp README.md $(DIST_DIR)/$(ARTIFACT_NAME)/ 2>/dev/null || true
	cp LICENSE $(DIST_DIR)/$(ARTIFACT_NAME)/ 2>/dev/null || true
	
	# Create build info file
	@echo "Project: $(PROJECT_NAME)" > $(DIST_DIR)/$(ARTIFACT_NAME)/BUILD_INFO.txt
	@echo "Version: $(VERSION)" >> $(DIST_DIR)/$(ARTIFACT_NAME)/BUILD_INFO.txt
	@echo "Git Hash: $(GIT_HASH)" >> $(DIST_DIR)/$(ARTIFACT_NAME)/BUILD_INFO.txt
	@echo "Git Branch: $(GIT_BRANCH)" >> $(DIST_DIR)/$(ARTIFACT_NAME)/BUILD_INFO.txt
	@echo "OS: $(OS)" >> $(DIST_DIR)/$(ARTIFACT_NAME)/BUILD_INFO.txt
	@echo "Architecture: $(ARCH)" >> $(DIST_DIR)/$(ARTIFACT_NAME)/BUILD_INFO.txt
	@echo "Build Time: $(BUILD_TIME)" >> $(DIST_DIR)/$(ARTIFACT_NAME)/BUILD_INFO.txt
	
	# Create archive
	cd $(DIST_DIR) && $(ARCHIVE_CMD) $(ARTIFACT_NAME)$(ARCHIVE_EXT) $(ARTIFACT_NAME)/
	
	@echo "Artifact created: $(DIST_DIR)/$(ARTIFACT_NAME)$(ARCHIVE_EXT)"

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

