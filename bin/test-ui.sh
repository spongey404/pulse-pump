#!/bin/bash -e
# End-to-end UI tests: XCUITest taps through the real app against the local Firebase emulators.
#
#   bin/test-ui.sh                                   everything in PulsePumpUITests on the first available iPhone simulator
#   bin/test-ui.sh --device "iPhone 17e"             pick the simulator
#   bin/test-ui.sh --only WorkoutUITests             one class (repeatable), or Class/testName for a single test
#   bin/test-ui.sh --result build/ui.xcresult        where the result bundle goes
#   bin/test-ui.sh --no-seed                         skip firebase/seed (social tests will fail without it)
#
# What it does: builds Cloud Functions, starts the auth + firestore + functions emulators (project "demo-pump", the real
# Firebase project is never contacted), seeds firebase/seed (friend1..8@example.com / "password"), then runs the UI
# target. The app is launched by each test with `-useFirebaseEmulator 1 -debugEmail … -debugAutoOnboard 1
# -createDevData …` (see CLAUDE.md "Dev data"), so every test gets a fresh emulator account and its own data.
# Failures keep a screenshot and the UI hierarchy in the xcresult; emulator logs go to build/emulator-logs/.
#
# Needs firebase-tools, Java 21+ and Node 24 on PATH (local fallbacks are added below).
set -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source bin/_common.sh

for p in /opt/homebrew/opt/openjdk@21/bin "$HOME"/.nvm/versions/node/v24*/bin; do [ -d "$p" ] && PATH="$p:$PATH"; done
export PATH

device=""; result="build/UITestResults.xcresult"; only=(); seed=true; inner=false
while [ $# -gt 0 ]; do
	case "$1" in
		--device) device="$2"; shift ;;
		--result) result="$2"; shift ;;
		--only) only+=("-only-testing:PulsePumpUITests/$2"); shift ;;
		--no-seed) seed=false ;;
		--run-tests) inner=true ;;          # internal: executed inside `firebase emulators:exec`
		--help|-h) sed -n '2,16p' "$0"; exit 0 ;;
		*) echo "Unknown option: $1" >&2; exit 1 ;;
	esac
	shift
done
[ ${#only[@]} -gt 0 ] || only=("-only-testing:PulsePumpUITests")

[ -n "$device" ] || device=$(pick_device)
[ -n "$device" ] || { echo "No iPhone simulator available" >&2; exit 1; }
spm_dir="build/SourcePackages"; dd="build/DerivedData"
dest="platform=iOS Simulator,name=$device"
# Ad-hoc signing: Firebase Auth stores its session in the keychain, which needs an (ad-hoc) signed app.
sign=(CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO)

if [ "$inner" = true ]; then
	if [ "$seed" = true ]; then
		echo "==> Seed emulators (firebase/seed)"
		[ -d firebase/seed/node_modules ] || npm --prefix firebase/seed ci >/dev/null
		node firebase/seed/seed.mjs >/dev/null
	fi
	# Start from a clean app + keychain so no login from an earlier run leaks into the first test.
	xcrun simctl boot "$device" 2>/dev/null || true
	xcrun simctl uninstall booted com.pulse.PulsePump 2>/dev/null || true
	xcrun simctl keychain booted reset 2>/dev/null || true
	xcodebuild test-without-building \
		-scheme PulsePump -destination "$dest" -derivedDataPath "$dd" \
		-parallel-testing-enabled NO "${only[@]}" -resultBundlePath "$result" "${sign[@]}" \
		| (command -v xcpretty >/dev/null && xcpretty || cat) | grep -E "error:|Test case .* (passed|failed)|\*\* TEST" || true
	exit 0
fi

echo "==> Xcode: $(xcodebuild -version | head -1) — simulator: $device"
echo "==> Build Cloud Functions"
[ -d firebase/functions/node_modules ] || npm --prefix firebase/functions ci
npm --prefix firebase/functions run build >/dev/null

echo "==> Build app + UI tests"
xcodebuild build-for-testing -scheme PulsePump -destination "$dest" \
	-derivedDataPath "$dd" -clonedSourcePackagesDirPath "$spm_dir" "${sign[@]}" \
	| (command -v xcpretty >/dev/null && xcpretty || cat) | grep -E "error:|BUILD|\*\* TEST BUILD" || true

echo "==> UI tests against the emulators"
rm -rf "$result" build/emulator-logs; mkdir -p build/emulator-logs
args=(); for a in "${only[@]}"; do args+=("--only" "${a#-only-testing:PulsePumpUITests/}"); done
[ "${only[0]}" = "-only-testing:PulsePumpUITests" ] && args=()
[ "$seed" = true ] || args+=("--no-seed")
status=0
firebase emulators:exec --only auth,firestore,functions --project demo-pump \
	"\"$PWD/bin/test-ui.sh\" --run-tests --device \"$device\" --result \"$result\" ${args[*]}" || status=$?
cp -f firebase-debug.log firestore-debug.log build/emulator-logs/ 2>/dev/null || true
rm -f firebase-debug.log firestore-debug.log ui-debug.log

if [ $status -ne 0 ] || ! xcresult_passed "$result"; then
	echo "UI tests FAILED — open $result in Xcode for screenshots / hierarchy (emulator logs: build/emulator-logs)" >&2
	exit 1
fi
echo "UI tests passed"
