#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# A Mac may have Command Line Tools selected even with Xcode installed.
if [[ -z "${DEVELOPER_DIR:-}" ]] && ! xcrun --find simctl >/dev/null 2>&1; then
  if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  else
    echo "Select a full Xcode installation with DEVELOPER_DIR." >&2
    exit 1
  fi
fi

mode="${1:-pr}"
result_dir="${TEST_OUTPUT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/staryigo-tests.XXXXXX")}"
mkdir -p "$result_dir"

case "$mode" in
  pr) selection=(-skip-testing:StarYiGoTests/NightlyAITests) ;;
  nightly) selection=(-only-testing:StarYiGoTests/NightlyAITests) ;;
  *) echo "Usage: $0 [pr|nightly]" >&2; exit 2 ;;
esac

# Pick a compatible iPhone from the newest available iOS runtime.
destination="${TEST_DESTINATION:-}"
if [[ -z "$destination" ]]; then
  sdk_version=$(xcrun --sdk iphonesimulator --show-sdk-version)
  device=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["devices"]
sdk_version = tuple(map(int, sys.argv[1].split(".")))
ios = "com.apple.CoreSimulator.SimRuntime.iOS-"
versions = sorted(
    (tuple(map(int, runtime.removeprefix(ios).split("-"))), devices)
    for runtime, devices in runtimes.items() if runtime.startswith(ios)
)
for version, devices in reversed(versions):
    if not (17, 6) <= version <= sdk_version:
        continue
    for device in devices:
        if device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit(0)
sys.exit("No compatible iPhone simulator found for the selected Xcode")
' "$sdk_version")
  destination="platform=iOS Simulator,id=$device"
fi

echo "Test results: $result_dir"
xcodebuild test -project 'StarYi Go.xcodeproj' -scheme StarYiGo \
  -destination "$destination" -derivedDataPath "$result_dir/DerivedData" \
  -resultBundlePath "$result_dir/$mode.xcresult" -parallel-testing-enabled NO \
  -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180 \
  -testLanguage en -testRegion US "${selection[@]}" CODE_SIGNING_ALLOWED=NO \
  2>&1 | tee "$result_dir/$mode.log"
