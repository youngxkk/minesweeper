#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ $# != 1 ]]; then
  echo "Usage: $0 <previous-StarYi-Go-git-ref>" >&2
  exit 2
fi
if [[ -z "${DEVELOPER_DIR:-}" ]] && ! xcrun --find simctl >/dev/null 2>&1; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

output="$(mktemp -d "${TMPDIR:-/tmp}/staryigo-upgrade.XXXXXX")"
old="$output/Previous"
mkdir "$old"
baseline="$(git rev-parse --verify --end-of-options "$1^{commit}")"
git archive "$baseline" | tar -xf - -C "$old"
project='StarYi Go.xcodeproj'
if [[ ! -f "$old/$project/project.pbxproj" ]]; then
  echo "The selected revision does not contain StarYi Go." >&2
  exit 2
fi
cp StarYiGoTests/UpgradeInstallationTests.swift "$old/StarYiGoTests/"
mkdir -p "$old/$project/xcshareddata/xcschemes"
cp "$project/xcshareddata/xcschemes/StarYiGoUpgrade.xcscheme" "$old/$project/xcshareddata/xcschemes/"

# Always create a fresh simulator. An upgrade test must never touch player data.
model="${UPGRADE_SIM_MODEL:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
runtime="${UPGRADE_SIM_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}"
device="$(xcrun simctl create 'StarYiGo Upgrade Test' "$model" "$runtime")"
trap 'xcrun simctl delete "$device"' EXIT
xcrun simctl bootstatus "$device" -b >"$output/boot.log" 2>&1
printf 'Upgrade results: %s\n' "$output"

run_test() {
  local source="$1" phase="$2" test_name="$3"
  xcodebuild test -project "$source/$project" -scheme StarYiGoUpgrade \
    -destination "platform=iOS Simulator,id=$device" \
    -derivedDataPath "$output/$phase-build" -resultBundlePath "$output/$phase.xcresult" \
    -only-testing:"StarYiGoTests/UpgradeInstallationTests/$test_name" \
    -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$output/$phase.log"
  if ! awk -v name="$test_name]" 'index($0, name) && index($0, "passed (") { found = 1 } END { exit !found }' "$output/$phase.log"; then
    echo "The expected upgrade test did not run: $test_name" >&2
    exit 1
  fi
}

run_test "$old" previous testSeedPreviousInstallation
run_test "$PWD" upgrade testUpgradePreservesArchiveSettingsAndFamilyProgress
