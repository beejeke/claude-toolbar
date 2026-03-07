APP_NAME = ClaudeToolbar
BUNDLE_ID = com.claudetoolbar.menubar
VERSION = 1.0.0
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app

.PHONY: build bundle install clean run dev

dev:
	swift run

build:
	swift build -c release

bundle: build
	@echo "Creating app bundle..."
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	@echo '<?xml version="1.0" encoding="UTF-8"?>' > $(APP_BUNDLE)/Contents/Info.plist
	@echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '<plist version="1.0"><dict>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '  <key>CFBundleExecutable</key><string>$(APP_NAME)</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '  <key>CFBundleIdentifier</key><string>$(BUNDLE_ID)</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '  <key>CFBundleName</key><string>$(APP_NAME)</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '  <key>CFBundleVersion</key><string>$(VERSION)</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '  <key>CFBundleShortVersionString</key><string>$(VERSION)</string>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '  <key>NSHighResolutionCapable</key><true/>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '  <key>LSUIElement</key><true/>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '  <key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><false/></dict>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo '</dict></plist>' >> $(APP_BUNDLE)/Contents/Info.plist
	@echo "Bundle created: $(APP_BUNDLE)"

install: bundle
	@echo "Installing to /Applications..."
	rm -rf /Applications/$(APP_BUNDLE)
	cp -R $(APP_BUNDLE) /Applications/
	@echo "Installed: /Applications/$(APP_BUNDLE)"
	open /Applications/$(APP_BUNDLE)

clean:
	rm -rf .build $(APP_BUNDLE)

run: bundle
	open $(APP_BUNDLE)
