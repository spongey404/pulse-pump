#!/bin/bash -e
# iOS integration tests: the real Swift sync / auth / social code against the local Firebase emulators.
#
#   bin/test-integration.sh                       build functions, start auth+firestore+functions emulators, run OreTests/Integration
#   bin/test-integration.sh --device "iPhone 17"  pick the simulator
#   bin/test-integration.sh --only SyncRoundTripEmulatorTests    just one suite (repeatable)
#   bin/test-integration.sh --result build/it.xcresult
#
# Needs firebase-tools, Java 21+ (Firestore emulator) and Node 24 on PATH (local fallbacks are added below).
# Everything runs against project "demo-pump"; the real Firebase project is never contacted.
# The tests are skipped unless PUMP_EMULATOR=1, which this script sets for the test host
# (xcodebuild forwards TEST_RUNNER_* variables to it). Parallel simulator clones are off: all tests share one emulator.
# Logs: build/emulator-logs/.
set -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source bin/_common.sh

# Local fallbacks (CI puts these on PATH through setup-java / setup-node).
for p in /opt/homebrew/opt/openjdk@21/bin "$HOME"/.nvm/versions/node/v24*/bin; do [ -d "$p" ] && PATH="$p:$PATH"; done
export PATH

device=""; result="build/IntegrationResults.xcresult"; only=()
while [ $# -gt 0 ]; do
	case "$1" in
		--device) device="$2"; shift ;;
		--result) result="$2"; shift ;;
		--only) only+=("-only-testing:OreTests/$2"); shift ;;
		--run-tests) inner=true ;;          # internal: executed inside `firebase emulators:exec`
		--help|-h) sed -n '2,12p' "$0"; exit 0 ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
	shift
done
[ ${#only[@]} -gt 0 ] || only=("-only-testing:OreTests/Integration")

[ -n "$device" ] || device=$(pick_device)
[ -n "$device" ] || { echo "No iPhone simulator available" >&2; exit 1; }
spm_dir="build/SourcePackages"; dd="build/DerivedData"
dest="platform=iOS Simulator,name=$device"
# Tests are selected by suite name (Swift Testing suites are addressed by type), so the folder filter
# falls back to listing every Integration suite explicitly.
suites=(AuthEmulatorTests ProfileEmulatorTests SyncRoundTripEmulatorTests SyncConflictEmulatorTests
	SocialGraphEmulatorTests SocialFeedEmulatorTests ChallengeEmulatorTests AccountDeletionEmulatorTests
	PermissionDeniedEmulatorTests)
if [ "${only[0]}" = "-only-testing:OreTests/Integration" ]; then
	only=(); for s in "${suites[@]}"; do only+=("-only-testing:OreTests/$s"); done
fi

if [ "$inner" = true ]; then
	TEST_RUNNER_PUMP_EMULATOR=1 xcodebuild test-without-building \
		-scheme Ore -destination "$dest" -derivedDataPath "$dd" \
		-parallel-testing-enabled NO "${only[@]}" -resultBundlePath "$result" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
		| (command -v xcpretty >/dev/null && xcpretty || cat) | grep -E "error:|Test case .* failed|✘|\*\* TEST" || true
	exit 0
fi

echo "==> Xcode: $(xcodebuild -version | head -1) — simulator: $device"
echo "==> Build Cloud Functions"
[ -d firebase/functions/node_modules ] || npm --prefix firebase/functions ci
npm --prefix firebase/functions run build >/dev/null

echo "==> Build tests"
xcodebuild build-for-testing -scheme Ore -destination "$dest" \
	-derivedDataPath "$dd" -clonedSourcePackagesDirPath "$spm_dir" CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO \
	| (command -v xcpretty >/dev/null && xcpretty || cat) | grep -E "error:|BUILD|\*\* TEST BUILD" || true

echo "==> Integration tests against the emulators"
rm -rf "$result" build/emulator-logs; mkdir -p build/emulator-logs
args=(); for a in "${only[@]}"; do args+=("--only" "${a#-only-testing:OreTests/}"); done
status=0
firebase emulators:exec --only auth,firestore,functions --project demo-pump \
	"\"$PWD/bin/test-integration.sh\" --run-tests --device \"$device\" --result \"$result\" ${args[*]}" || status=$?
cp -f firebase-debug.log firestore-debug.log build/emulator-logs/ 2>/dev/null || true
rm -f firebase-debug.log firestore-debug.log ui-debug.log

if [ $status -ne 0 ] || ! xcresult_passed "$result"; then
	echo "Integration tests FAILED — open $result in Xcode for details (emulator logs: build/emulator-logs)" >&2
	exit 1
fi
echo "Integration tests passed"
