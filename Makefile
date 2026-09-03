.PHONY: build bundle run selftest clean

# Compile only.
build:
	swift build

# Build the BusBar.app bundle (release).
bundle:
	./Scripts/bundle.sh release

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
