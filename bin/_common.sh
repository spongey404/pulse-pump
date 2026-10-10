#!/bin/bash
# Shared helpers for bin/test.sh and bin/test-integration.sh (sourced, not executed).

# Prints the first available iPhone simulator name (newest runtime first) so scripts survive simulator renames.
pick_device() {
	xcrun simctl list devices available | grep -E "^ +iPhone" | head -1 | sed -E 's/^ +(.*) \([0-9A-F-]{36}\).*/\1/'
}

# 0 when the xcresult bundle's overall result is Passed. Prints the counts to stderr otherwise.
xcresult_passed() {
	local result="$1"
	if xcrun xcresulttool get test-results summary --path "$result" 2>/dev/null | grep -q '"result" : "Passed"'; then
		return 0
	fi
	xcrun xcresulttool get test-results summary --path "$result" 2>/dev/null | grep -E '"(failedTests|passedTests|skippedTests|totalTestCount)"' >&2 || true
	return 1
}
