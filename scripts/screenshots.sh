#!/bin/bash
# Capture every locked screen into screenshots/<shortsha>/.
# Uses Samara-Gate-iPhone only. Never boots SpikeWorker-iPhone17Pro.
set -euo pipefail

ROOT="/Users/seanholt/cursor-worker/SamaraConditions"
DERIVED="/Users/seanholt/cursor-builds/samara-conditions/DerivedData"
DEVICE_NAME="Samara-Gate-iPhone"
BUNDLE="com.seanholt.samaraconditions"
NOW="2026-11-11T17:00:00-06:00"

SHA="$(git -C "$ROOT" rev-parse --short=12 HEAD)"
OUT="$ROOT/screenshots/$SHA"
mkdir -p "$OUT"

xcodebuild \
  -project "$ROOT/ios/SamaraConditions.xcodeproj" \
  -scheme SamaraConditions \
  -destination "platform=iOS Simulator,name=$DEVICE_NAME" \
  -derivedDataPath "$DERIVED" \
  build

APP="$(find "$DERIVED/Build/Products" -type d -name 'SamaraConditions.app' -path '*iphonesimulator*' | head -1)"
UDID="$(xcrun simctl list devices | awk -F '[()]' -v name="$DEVICE_NAME" '$0 ~ name" \\(" { print $2; exit }')"
if [[ -z "$UDID" ]]; then
  echo "missing simulator $DEVICE_NAME" >&2
  exit 1
fi

xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"

status_bar() {
  xcrun simctl status_bar "$UDID" override \
    --time "9:41" \
    --batteryState charged \
    --batteryLevel 100 \
    --cellularMode active \
    --cellularBars 4 \
    --wifiMode active \
    --wifiBars 3
}

shot() {
  local name="$1"
  shift
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE" -use-fixture -now "$NOW" "$@" >/dev/null
  sleep 2
  status_bar
  sleep 0.4
  xcrun simctl io "$UDID" screenshot "$OUT/$name.png" >/dev/null
  echo "$OUT/$name.png"
}

shot today-beach -ui-state fresh -tab today -activity beach
shot today-beach-low-tide -ui-state fresh -tab today -activity beach -low-tide 1
shot today-soccer-sun -ui-state fresh -tab today -activity soccer-sun
shot today-soccer-shade -ui-state fresh -tab today -activity soccer-shade
shot today-pool -ui-state fresh -tab today -activity pool
shot today-jungle -ui-state fresh -tab today -activity jungle
shot week-heat -ui-state fresh -tab week -week heat -activity beach
shot week-rain -ui-state fresh -tab week -week rain
shot week-cloud -ui-state fresh -tab week -week cloud
shot week-sea -ui-state fresh -tab week -week sea
shot state-loading -ui-state loading
shot state-fresh -ui-state fresh
shot state-stale -ui-state stale
shot state-stale-tide -ui-state stale-tide
shot state-offline -ui-state offline
shot state-error -ui-state error
shot state-imn -ui-state imn
shot sources -ui-state fresh -show-sources 1

echo "wrote $OUT"
