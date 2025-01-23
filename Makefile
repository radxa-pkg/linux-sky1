PROJECT ?= linux-sky1

KERNEL_FORK ?= sky1
ARCH ?= arm64
CROSS_COMPILE ?= aarch64-linux-gnu-
DPKG_FLAGS ?= -d
KERNEL_DEFCONFIG ?= defconfig cix.config radxa.config radxa_custom.config

KMAKE ?= $(MAKE) -C "$(SRC-KERNEL)" -j$(shell nproc) \
			ARCH=$(ARCH) CROSS_COMPILE=$(CROSS_COMPILE) HOSTCC=$(CROSS_COMPILE)gcc \
			KDEB_COMPRESS="xz" KDEB_CHANGELOG_DIST="unstable" DPKG_FLAGS=$(DPKG_FLAGS) \
			LOCALVERSION=-$(shell dpkg-parsechangelog -S Version | cut -d "-" -f 2)-$(KERNEL_FORK) \
			KERNELRELEASE=$(shell dpkg-parsechangelog -S Version)-$(KERNEL_FORK) \
			KDEB_PKGVERSION=$(shell dpkg-parsechangelog -S Version)

.PHONY: all
all: build

#
# Test
#
.PHONY: test
test:

#
# Build
#
.PHONY: build
build: build-defconfig build-bindeb

SRC-KERNEL	:=	src

.PHONY: build-defconfig
build-defconfig: $(SRC-KERNEL)
	$(KMAKE) $(KERNEL_DEFCONFIG)

.PHONY: build-dtbs
build-dtbs: $(SRC-KERNEL)
	$(KMAKE) dtbs

.PHONY: build-all
build-all: $(SRC-KERNEL)
	$(KMAKE) all

.PHONY: build-bindeb
build-bindeb: $(SRC-KERNEL) build-all
	$(KMAKE) bindeb-pkg
	mv linux-*_arm64.deb linux-upstream*_arm64.changes linux-upstream*_arm64.buildinfo ../

#
# Clean
#
.PHONY: distclean
distclean: clean

.PHONY: clean
clean: clean-deb

.PHONY: clean-deb
clean-deb:
	rm -rf debian/.debhelper debian/${PROJECT}*/ debian/linux-*/ debian/tmp/ debian/debhelper-build-stamp debian/files debian/*.debhelper.log debian/*.postrm.debhelper debian/*.substvars
	rm -f linux-*_arm64.deb linux-upstream*_arm64.changes linux-upstream*_arm64.buildinfo

#
# Release
#
.PHONY: dch
dch: debian/changelog
	EDITOR=true gbp dch --ignore-branch --multimaint-merge --commit --release --dch-opt=--upstream

.PHONY: deb
deb: debian
	debuild --no-lintian --lintian-hook "lintian --fail-on error,warning --suppress-tags bad-distribution-in-changes-file -- %p_%v_*.changes" --no-sign -b

.PHONY: release
release:
	gh workflow run .github/workflows/new_version.yml --ref $(shell git branch --show-current)
