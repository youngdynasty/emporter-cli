# ---------------------------------------------------------------------------------------------------

PLIST = emporter-cli/Support/Info.plist
PLIST_GET = $(shell plutil -extract "$(1)" xml1 -o - "$(PLIST)" | xmllint -xpath '/plist/string/text()' -)
PLIST_SET = @plutil -replace "$(1)" -string "$(2)" "$(PLIST)"

PLIST_VERSION=$(call PLIST_GET,CFBundleShortVersionString)
PLIST_BUILD_N=$(call PLIST_GET,CFBundleVersion)

KEYCHAIN_GITHUB=emporter-cli-gh

KEYCHAIN_KEY = $(shell security -q find-generic-password -s "$(1)" 2> /dev/null | grep acct | cut -d '=' -f 2)
KEYCHAIN_SECRET = $(shell security -q find-generic-password -s "$(1)" -w 2> /dev/null)
KEYCHAIN_DELETE = $(shell security delete-generic-password -s "$(1)" -a "$(2)" > /dev/null 2>&1 || true)
KEYCHAIN_STORE = $(shell security add-generic-password -s "$(1)" -a "$(2)" -p "$(3)")

# ---------------------------------------------------------------------------------------------------
# Building

.PHONY: all
all: bump build

# Bump version number
.PHONY: bump
bump: 
	@if [ -z "$(VERSION)" ]; then echo "Missing version number."; exit 1; fi

	$(eval NEW_BUILD_N=$(shell git rev-list --count HEAD))
	$(call PLIST_SET,CFBundleVersion,$(NEW_BUILD_N))
	$(call PLIST_SET,CFBundleShortVersionString,$(VERSION))

	$(eval PLIST_VERSION=$(VERSION))
	$(eval PLIST_BUILD_N=$(NEW_BUILD_N))

	@echo "==> Bumped version to \033[1m$(PLIST_VERSION) (build $(PLIST_BUILD_N))\033[0m"

# Build archive and extract its contents into build/
.PHONY: build
build:
	@echo "==> Building version \033[1m$(PLIST_VERSION)\033[0m (build $(PLIST_BUILD_N))..."

	@xcodebuild -quiet -allowProvisioningUpdates -configuration Release -scheme emporter -archivePath build/emporter.xcarchive archive
	@cd build && cp -afR emporter.xcarchive/Products/usr/local/bin/* emporter.xcarchive/dSYMs/* .

# Clean build directory
.PHONY: clean
clean:
	@rm -fr build/

# ---------------------------------------------------------------------------------------------------
# Release / Deployment

# Build and sign for distribution, verify via the install script, and open the result
.PHONY: release
release: github-creds
release: build
release: PACKAGE_TARBALL=emporter.tar.gz
release: PACKAGE_DYSM=emporter.dSYM.tar.gz
release:
	@rm -fr build/release && mkdir -p build/release

	@echo "==> Signing for distribution..."
	@cd build && codesign -fs "Developer ID Application: Young Dynasty" emporter

	@echo "==> Building package..."
	$(eval WORK_DIR=$(shell mktemp -d))
	@trap 'rm -fr "$(WORK_DIR)"' EXIT; \
		mkdir -p $(WORK_DIR)/contents/usr/local/bin \
		&& cp build/emporter $(WORK_DIR)/contents/usr/local/bin/. \
		&& pkgbuild \
			--install-location / \
			--root "$(WORK_DIR)/contents" \
			--ownership preserve \
			--identifier net.youngdynasty.emporter-cli \
			--sign "Developer ID Installer: Young Dynasty" \
			--version $(PLIST_VERSION) \
			$(WORK_DIR)/emporter.pkg \
		&& productbuild  \
			--distribution emporter-cli/Support/Distribution.plist \
			--package-path "$(WORK_DIR)" \
			--sign "Developer ID Installer: Young Dynasty" \
			--version $(PLIST_VERSION) \
			build/release/emporter.pkg

	@echo "==> Testing package install script..."
	@PACKAGE=build/release/emporter.pkg sh ./Scripts/install.sh

	@echo "==> Creating tarball..."
	@cd build/release \
		&& tar cfz emporter.tar.gz -C .. emporter \
		&& tar cfz emporter.dSYM.tar.gz -C .. emporter.dSYM

	@echo "==> Testing tarball install script..."
	@PACKAGE=build/release/emporter.tar.gz sh ./Scripts/install-tarball.sh

	@echo "==> Uploading..."
	@GITHUB_CREDS=$(GITHUB_CREDS) sh Scripts/release.sh $(PLIST_VERSION) build/release/*


.PHONY: deploy
deploy:
	@echo "==> Updating install scripts..."
	@sed -i '' -e "s/.*PACKAGE_VERSION\=.*$$/PACKAGE_VERSION=$(PLIST_VERSION)/" Scripts/install-tarball.sh
	@sed -i '' -e "s/.*PACKAGE_VERSION\=.*$$/PACKAGE_VERSION=$(PLIST_VERSION)/" Scripts/install.sh

	@echo "==> Verifying install scripts..."
	@for SCRIPT in Scripts/install*.sh; do sh $$SCRIPT; done;

	@gsutil -h "Content-Type:text/plain; charset=utf-8" -h "Cache-Control:public, max-age=3600" \
		cp -a public-read Scripts/install*.sh gs://emporter.io/cli/

# ---------------------------------------------------------------------------------------------------
# Credentials

.PHONY: .check-creds-args
.check-creds-args:
	@if [ -z "$(KEY)" ]; then echo "*** KEY is required."; exit 1; fi 
	@if [ -z "$(SECRET)" ]; then echo "*** SECRET is required."; exit 1; fi 

.PHONY: github-creds-store
github-creds-store: .check-creds-args
	$(call KEYCHAIN_DELETE,$(KEYCHAIN_GITHUB),$(KEY))
	$(call KEYCHAIN_STORE,$(KEYCHAIN_GITHUB),$(KEY),$(SECRET))
	
.PHONY: github-creds
github-creds: KEY=$(call KEYCHAIN_KEY,$(KEYCHAIN_GITHUB))
github-creds: SECRET=$(call KEYCHAIN_SECRET,$(KEYCHAIN_GITHUB))
github-creds:
	@if [ -z "$(KEY)" ] || [ -z "$(SECRET)" ]; then echo "*** Missing GitHub credentials. Run 'make github-creds-store' to continue."; exit 1; fi 
	
	$(eval GITHUB_CREDS=$(KEY):$(SECRET))
