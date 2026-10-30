#!/bin/bash -e
# Build and test Ore the same way CI does.
#
#   bin/test.sh                 unit tests (OreTests) on the first available iPhone simulator
#   bin/test.sh --release       also do a Release build and check DEBUG-only code is compiled out
#   bin/test.sh --device "iPhone 17 Pro" --result build/tests.xcresult
#
# UI tests (OreUITests) are not run here: they need the Firebase emulators, see bin/test-ui.sh. They are
# excluded by -only-testing:OreTests below.
set -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source bin/_common.sh

device=""; release=false; result="build/TestResults.xcresult"
while [ $# -gt 0 ]; do
	case "$1" in
		--device) device="$2"; shift ;;
		--result) result="$2"; shift ;;
		--release) release=true ;;
		--help|-h) sed -n '2,10p' "$0"; exit 0 ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
	shift
done

if [ -z "$device" ]; then
	# First available iPhone (newest runtime first) so the script survives simulator renames.
	device=$(pick_device)
	[ -n "$device" ] || { echo "No iPhone simulator available" >&2; exit 1; }
fi
echo "==> Xcode: $(xcodebuild -version | head -1) — simulator: $device"

spm_dir="build/SourcePackages"          # cached by CI keyed on Package.resolved
dd="build/DerivedData"
rm -rf "$result"

echo "==> Unit tests"
xcodebuild test \
	-scheme Ore \
	-destination "platform=iOS Simulator,name=$device" \
	-derivedDataPath "$dd" -clonedSourcePackagesDirPath "$spm_dir" \
	-only-testing:OreTests \
	-resultBundlePath "$result" \
	CODE_SIGNING_ALLOWED=NO \
	| (command -v xcpretty >/dev/null && xcpretty || cat) | grep -E "error:|Test case .* failed|\*\* TEST" || true
# The pipeline above only filters output; ask the result bundle for the verdict.
if ! xcresult_passed "$result"; then
	echo "Unit tests FAILED — open $result in Xcode for details" >&2
	exit 1
fi
echo "Unit tests passed"

if $release; then
	echo "==> Release build (app + widget extension)"
	xcodebuild build -scheme Ore -configuration Release \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath "build/DerivedDataRelease" -clonedSourcePackagesDirPath "$spm_dir" \
		CODE_SIGNING_ALLOWED=NO | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
	bin_path=$(find build/DerivedDataRelease/Build/Products -name "Ore" -path "*Ore.app/Ore" | head -1)
	[ -n "$bin_path" ] || { echo "Release binary not found" >&2; exit 1; }
	# DEBUG-only dev data / fixtures must not ship.
	if nm "$bin_path" 2>/dev/null | grep -qE "DevDataService|DevDataFactory|DevDataConfig"; then
		echo "DEBUG-only DevData symbols found in the Release binary" >&2; exit 1
	fi
	echo "Release build OK, no DevData symbols"
fi
