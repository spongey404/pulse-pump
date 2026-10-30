#!/bin/bash -e
# Build Ore, install it on a simulator with a clean store, and launch it with the dev-data seeder.
# (The iOS equivalent of `manage.py createdevdata` — see Ore/DevData/DevDataConfig.swift.)
set -o pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

device="iPhone 17 Pro"
scenario="busy"; weeks=16; seed=42; units="kg"
plus=0; draft=0; build=true; keep=false

function show_help() {
	cat <<EOF
Usage: $0 [options]

  --scenario NAME   busy (default) | lapsed | new-user
  --weeks N         weeks of history, 2-52 (default 16)
  --seed N          RNG seed; same seed = same data (default 42)
  --units kg|lb     display units (default kg)
  --plus            pretend Supernova is active
  --draft           also leave one in-progress workout (Continue card)
  --device NAME     simulator name (default "iPhone 17 Pro")
  --no-build        reuse the last build in build/DerivedData
  --keep            don't erase the existing app/store first (seeder skips if a user exists)

Dev dataset: user "Dev Lifter" (@dev_lifter), PPL split with days, Home Gym + Commercial Gym
profiles, Push/Pull/Leg templates, ~5 sessions/week with progressive overload, warm-ups, one
deload week, fresh PRs, a 60-day bodyweight log, and demo friends/feed/challenges.
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--scenario) scenario="$2"; shift ;;
		--weeks) weeks="$2"; shift ;;
		--seed) seed="$2"; shift ;;
		--units) units="$2"; shift ;;
		--plus) plus=1 ;;
		--draft) draft=1 ;;
		--device) device="$2"; shift ;;
		--no-build) build=false ;;
		--keep) keep=true ;;
		--help|-h) show_help; exit 0 ;;
		*) echo "Unknown option: $1" >&2; show_help; exit 1 ;;
	esac
	shift
done

dd="build/DerivedData"
bundle="com.pulse.PulsePump"

if $build; then
	echo "==> Building"
	xcodebuild -scheme Ore -destination "platform=iOS Simulator,name=$device" \
		-derivedDataPath "$dd" build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | sort -u
fi
app="$dd/Build/Products/Debug-iphonesimulator/Ore.app"
[ -d "$app" ] || { echo "No build at $app" >&2; exit 1; }

echo "==> Preparing simulator: $device"
xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl terminate booted "$bundle" 2>/dev/null || true
if ! $keep; then xcrun simctl uninstall booted "$bundle" 2>/dev/null || true; fi
xcrun simctl install booted "$app"

echo "==> Seeding ($scenario, $weeks weeks, seed $seed, $units)"
xcrun simctl launch booted "$bundle" \
	-createDevData 1 -devDataReset 1 \
	-devDataScenario "$scenario" -devDataWeeks "$weeks" -devDataSeed "$seed" -devDataUnits "$units" \
	-devDataPlus "$plus" -devDataDraft "$draft" >/dev/null

sleep 4
xcrun simctl spawn booted log show --last 1m --style compact \
	--predicate 'eventMessage CONTAINS "[DevData]"' 2>/dev/null | grep "DevData" | sed -E 's/.*(\[DevData\] .*)/\1/' | tail -3
echo "Done. The app is running on $device with the dev dataset."
