# Makefile for building and publishing cross-platform artifacts
# Supports Linux, macOS, Windows with proper architecture detection

# Check required variables from calling makefile
ifndef INSTALLED.HOST.DIR
$(error INSTALLED.HOST.DIR must be defined by the calling Makefile)
endif

ifndef DOWNLOADS.DIR
$(error DOWNLOADS.DIR must be defined by the calling Makefile)
endif

ifndef PACKAGE.DIR
$(error PACKAGE.DIR must be defined by the calling Makefile)
endif

ifndef DEPENDENCIES
$(error DEPENDENCIES must be defined by the calling Makefile)
endif

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

# Package version (should be provided by calling Makefile)
ifndef PACKAGE_VERSION
ARTIFACT.NAME := $(PROJECT_NAME)-$(VERSION)-$(OS)-$(ARCH)
else
ARTIFACT.NAME := $(PROJECT_NAME)-$(VERSION)-$(PACKAGE_VERSION)-$(OS)-$(ARCH)
endif

# Artifact naming
#
FULL_ARTIFACT.NAME := $(ARTIFACT.NAME)-$(BUILD_TIME)

BINARY_EXT :=
ARCHIVE_EXT := .tar.gz
ARCHIVE_CMD := tar -czf

AWS.BIN=aws

# Display build information
.PHONY: info
info:
	@echo "Build Information:"
	@echo "  Project: $(PROJECT_NAME)"
	@echo "  OS: $(OS)"
	@echo "  Architecture: $(ARCH)"
	@echo "  Version: $(VERSION) ($(VERSION_TYPE))"
	@echo "  Package Version: $(PACKAGE_VERSION)"
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
	@echo https://$(S3.BUCKET).s3.amazonaws.com/$(ARTIFACT.NAME).tar.gz
	@echo https://$(S3.BUCKET).s3.amazonaws.com/$(ARTIFACT.NAME).tar.gz.md5


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
	@echo "  upload       - Upload to s3 bucket"
	@echo "  build-all    - Cross-compile for all targets"
	@echo "  package-all  - Package all cross-compiled targets"
	@echo "  clean        - Remove build artifacts"
	@echo ""
	@echo "Cross-compilation targets:"
	@echo "  build-linux-x86_64   build-linux-arm64"
	@echo "  build-windows-x86_64 build-macos-x86_64 build-macos-arm64"


# Function to get version for a package
define get_version
$(word 2,$(subst :, ,$(filter $1:%,$(DEPENDENCIES))))
endef

# Function to get URL for a package
define get_url
https://$(S3.BUCKET).s3.amazonaws.com/$(1)-$(call get_version,$(1))-$(OS)-$(ARCH).tar.gz
endef

DEP_NAMES := $(foreach dep,$(DEPENDENCIES),$(word 1,$(subst :, ,$(dep))))

# Force install approach - no .installed file checking
FORCE_INSTALL_DEPS := $(foreach dep,$(DEP_NAMES),force-install-$(dep))

INSTALLED_DEPS := $(FORCE_INSTALL_DEPS)

define DEPENDENCY_TEMPLATE
$(INSTALLED.HOST.DIR)/.$(1)-installed: | $(INSTALLED.HOST.DIR)
	@echo "Unpacking dependency: $(1) version $(call get_version,$(1))"
	@echo "Downloading $(call get_url,$(1))..."
	@mkdir -p $(DOWNLOADS.DIR)
	@cd $(DOWNLOADS.DIR) && curl -fsSL "$(call get_url,$(1))" -o $(1)-$(call get_version,$(1))-$(OS)-$(ARCH).tar.gz
	@cd $(INSTALLED.HOST.DIR) && tar -xzf $(DOWNLOADS.DIR)/$(1)-$(call get_version,$(1))-$(OS)-$(ARCH).tar.gz --strip-components=1
	@touch $(INSTALLED.HOST.DIR)/.$(1)-installed
	@echo "✓ $(1) $(call get_version,$(1)) unpacked to $(INSTALLED.HOST.DIR)"

.PHONY: force-install-$(1)
force-install-$(1): | $(INSTALLED.HOST.DIR)
	@echo "Force unpacking dependency: $(1) version $(call get_version,$(1))"
	@echo "Downloading $(call get_url,$(1))..."
	@mkdir -p $(DOWNLOADS.DIR)
	@cd $(DOWNLOADS.DIR) && curl -fsSL "$(call get_url,$(1))" -o $(1)-$(call get_version,$(1))-$(OS)-$(ARCH).tar.gz
	@cd $(INSTALLED.HOST.DIR) && tar -xzf $(DOWNLOADS.DIR)/$(1)-$(call get_version,$(1))-$(OS)-$(ARCH).tar.gz --strip-components=1
	@echo "✓ $(1) $(call get_version,$(1)) force unpacked to $(INSTALLED.HOST.DIR)"

endef

# Generate targets for all dependencies
$(foreach dep_name,$(DEP_NAMES),$(eval $(call DEPENDENCY_TEMPLATE,$(dep_name))))

dependencies: $(INSTALLED_DEPS)

.PHONY: list-deps
list-deps:
	@echo "Project Dependencies:"
	@echo "===================="
	@$(foreach dep,$(DEPENDENCIES),echo "  $(dep)";)
	@echo ""
	@echo "Installed Dependencies:"
	@echo "======================"
	@$(foreach dep,$(DEP_NAMES), \
		if [ -f "$(DEPS_DIR)/$(dep)/.installed" ]; then \
			echo "  ✓ $(dep) $(call get_version,$(dep))"; \
		else \
			echo "  ✗ $(dep) $(call get_version,$(dep)) (not installed)"; \
		fi;)


