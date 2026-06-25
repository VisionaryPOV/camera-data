#!/bin/bash
# Clears cached provisioning profiles so Xcode regenerates them with current portal capabilities.
set -euo pipefail

PROFILE_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
if [[ -d "$PROFILE_DIR" ]]; then
  count=$(find "$PROFILE_DIR" -name '*.mobileprovision' | wc -l | tr -d ' ')
  find "$PROFILE_DIR" -name '*.mobileprovision' -delete
  echo "Removed $count cached provisioning profile(s)."
else
  echo "No provisioning profile cache found."
fi

echo "Next in Xcode:"
echo "  1. Xcode → Settings → Accounts → Download Manual Profiles"
echo "  2. Select PAID team (not Personal Team) on CameraData + CameraDataWidget"
echo "  3. Product → Clean Build Folder, then build"