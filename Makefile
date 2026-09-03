.PHONY: build bundle run selftest release install clean

# Compile only.
build:
	swift build

# Build the BusBar.app bundle (release).
bundle:
	./Scripts/bundle.sh release

# Build a universal, signed BusBar.app + distributable zip.
release:
	./Scripts/release.sh

# Install the built app into /Applications (builds first if needed).
install: bundle
	@rm -rf /Applications/BusBar.app
	cp -R BusBar.app /Applications/BusBar.app
	@echo "Installed to /Applications/BusBar.app — launch it from Spotlight or Finder."

# Build + launch the menu bar app for development.
# Runs the binary inside the bundle directly so it inherits the shell env and finds .env,
# while still resolving Bundle.main to the .app.
run: bundle
	@set -a; [ -f .env ] && . ./.env; set +a; ./BusBar.app/Contents/MacOS/BusBar

# Headless end-to-end check of the data pipeline (no UI).
selftest:
	swift build
	@set -a; [ -f .env ] && . ./.env; set +a; ./.build/debug/BusBar --selftest

clean:
	swift package clean
	rm -rf BusBar.app
