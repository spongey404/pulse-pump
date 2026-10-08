#!/bin/bash -e
# Build and test Pump the same way CI does.
#
#   bin/test.sh                 unit tests (PulsePumpTests) on the first available iPhone simulator
#   bin/test.sh --release       also do a Release build and check DEBUG-only code is compiled out
#   bin/test.sh --device "iPhone 17 Pro" --result build/tests.xcresult
#
# UI tests (PulsePumpUITests) are not run: the suite is stale (see audit/widgets-tests.md) and is
# skipped until it is rewritten.
set -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

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
	device=$(xcrun simctl list devices available | grep -E "^ +iPhone" | head -1 | sed -E 's/^ +(.*) \([0-9A-F-]{36}\).*/\1/')
	[ -n "$device" ] || { echo "No iPhone simulator available" >&2; exit 1; }
fi
echo "==> Xcode: $(xcodebuild -version | head -1) — simulator: $device"

spm_dir="build/SourcePackages"          # cached by CI keyed on Package.resolved
dd="build/DerivedData"
rm -rf "$result"

echo "==> Unit tests"
xcodebuild test \
	-scheme PulsePump \
	-destination "platform=iOS Simulator,name=$device" \
	-derivedDataPath "$dd" -clonedSourcePackagesDirPath "$spm_dir" \
	-only-testing:PulsePumpTests \
	-resultBundlePath "$result" \
	CODE_SIGNING_ALLOWED=NO \
	| (command -v xcpretty >/dev/null && xcpretty || cat) | grep -E "error:|Test case .* failed|\*\* TEST" || true
# The pipeline above only filters output; ask the result bundle for the verdict.
if ! xcrun xcresulttool get test-results summary --path "$result" 2>/dev/null | grep -q '"result" : "Passed"'; then
	echo "Unit tests FAILED — open $result in Xcode for details" >&2
	xcrun xcresulttool get test-results summary --path "$result" 2>/dev/null | grep -E '"(failedTests|passedTests|totalTestCount)"' >&2 || true
	exit 1
fi
echo "Unit tests passed"

if $release; then
	echo "==> Release build (app + widget extension)"
	xcodebuild build -scheme PulsePump -configuration Release \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath "build/DerivedDataRelease" -clonedSourcePackagesDirPath "$spm_dir" \
		CODE_SIGNING_ALLOWED=NO | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
	bin_path=$(find build/DerivedDataRelease/Build/Products -name "PulsePump" -path "*PulsePump.app/PulsePump" | head -1)
	[ -n "$bin_path" ] || { echo "Release binary not found" >&2; exit 1; }
	# DEBUG-only dev data / fixtures must not ship.
	if nm "$bin_path" 2>/dev/null | grep -qE "DevDataService|DevDataFactory|DevDataConfig"; then
		echo "DEBUG-only DevData symbols found in the Release binary" >&2; exit 1
	fi
	echo "Release build OK, no DevData symbols"
fi
