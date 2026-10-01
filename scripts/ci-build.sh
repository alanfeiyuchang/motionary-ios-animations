#!/usr/bin/env bash
# Builds the app for the iOS Simulator with the newest installed Xcode matching the given prefix
# (e.g. Xcode_26) and prints compiler errors last so they are visible at the end of CI logs.
# The build keeps going after an error, so one run lists every failing file, not just the first.
set -uo pipefail
PREFIX="${1:-Xcode_26}"
PICK=$(ls -d /Applications/${PREFIX}*.app | grep -v -i beta | sort -V | tail -n 1)
echo "Using $PICK"
sudo xcode-select -s "$PICK"
xcodebuild -version
xcodebuild \
  -project MotionLab.xcodeproj \
  -scheme MotionLab \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  -IDEBuildingContinueBuildingAfterErrors=YES \
  build > build.log 2>&1
STATUS=$?
if [ $STATUS -ne 0 ]; then
  tail -n 30 build.log
  echo "================ COMPILER ERRORS ================"
  grep -E "error:" build.log | sed -E 's#^.*/MotionLab/#MotionLab/#' | sort -u | head -n 300
  exit 1
fi
echo "================ WARNINGS ================"
grep -E "warning:" build.log | grep -v appintents | sed -E 's#^.*/MotionLab/#MotionLab/#' | sort -u | head -n 100 || true
echo "Build succeeded"
