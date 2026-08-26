# Builds gafferongames.com with a pinned Hugo. The system hugo is never used:
# the exact release is downloaded per platform, checksum verified against the
# official release checksums, and cached under dist/ keyed by version.

HUGO_VERSION = 0.124.1

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

ifeq ($(UNAME_S),Darwin)
HUGO_TARBALL = hugo_extended_$(HUGO_VERSION)_darwin-universal.tar.gz
HUGO_SHA256 = 94d4c97cfa21221a4348abd35159c2eaa0533852562ca341fc910fe43b4bdd7d
SHA256_CHECK = shasum -a 256 -c
else ifeq ($(UNAME_M),aarch64)
HUGO_TARBALL = hugo_extended_$(HUGO_VERSION)_linux-arm64.tar.gz
HUGO_SHA256 = 5afde01bcff49d7a22b96844c329f6cbb175d8a30456e17ef47df0c3e6f60135
SHA256_CHECK = sha256sum -c
else
HUGO_TARBALL = hugo_extended_$(HUGO_VERSION)_linux-amd64.tar.gz
HUGO_SHA256 = 55f5a5f6a4c923457b2ed4e2b00c251eabfe43d8d4afbe2ada92d9759c5e0410
SHA256_CHECK = sha256sum -c
endif

HUGO_DIST = dist/hugo-$(HUGO_VERSION)
HUGO = $(HUGO_DIST)/hugo
HUGO_URL = https://github.com/gohugoio/hugo/releases/download/v$(HUGO_VERSION)/$(HUGO_TARBALL)

.PHONY: build local

build: $(HUGO)
	$(HUGO)

local: $(HUGO)
	bash -c "sleep 0.25 && /Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome http://127.0.0.1:1313" &
	mkdir -p public/static
	$(HUGO) server --watch -D -F

$(HUGO):
	mkdir -p $(HUGO_DIST)
	curl -fsSL $(HUGO_URL) -o $(HUGO_DIST)/$(HUGO_TARBALL)
	cd $(HUGO_DIST) && echo "$(HUGO_SHA256)  $(HUGO_TARBALL)" | $(SHA256_CHECK)
	tar xzf $(HUGO_DIST)/$(HUGO_TARBALL) -C $(HUGO_DIST) hugo
	rm $(HUGO_DIST)/$(HUGO_TARBALL)
	$(HUGO) version
