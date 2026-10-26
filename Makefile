APP_NAME := MenuBarKit
APP      := build.noindex/$(APP_NAME).app
DEST     := /Applications/$(APP_NAME).app

.PHONY: build run install update uninstall signing clean

## build: compile a release build and wrap it in build.noindex/MenuBarKit.app
build:
	swift build -c release
	scripts/bundle.sh

## run: build and launch from build.noindex/ without installing
run: build
	@scripts/quit.sh
	open $(APP)

## install: build, copy to /Applications and (re)launch
install: build
	@scripts/quit.sh
	rm -rf $(DEST)
	cp -R $(APP) $(DEST)
	open $(DEST)

## update: pull the latest source, then install
update:
	git pull --ff-only
	$(MAKE) install

## uninstall: quit and remove the app (settings stay in UserDefaults)
uninstall:
	@scripts/quit.sh
	rm -rf $(DEST)

## signing: create the local code signing certificate (once per Mac)
signing:
	scripts/setup-signing.sh

clean:
	rm -rf .build build.noindex
