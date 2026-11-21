#!/usr/bin/env bash
# Builds Refine (host app + Refine keyboard).
#
#   ./build.sh          generate the Xcode project and open it
#   ./build.sh --sim    build, install and launch in the iOS Simulator
#   ./build.sh --ipa    build an unsigned build/Refine.ipa for SideStore to sign and install
#
# Simulator device: SIM_DEVICE="iPhone 17 Pro" ./build.sh --sim
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f Vendor/refine-popclip/RefineCore/Package.swift ]; then
  git submodule update --init
fi
command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }
xcodegen generate --quiet

DERIVED="build/DerivedData"
run_xcodebuild() {
  # Quiet output; show errors and warnings only.
  xcodebuild -project Refine.xcodeproj -scheme Refine -derivedDataPath "$DERIVED" -quiet "$@"
}

case "${1:-}" in
  --sim)
    DEVICE="${SIM_DEVICE:-iPhone 17}"
    run_xcodebuild -configuration Debug -destination "platform=iOS Simulator,name=$DEVICE" build
    APP="$DERIVED/Build/Products/Debug-iphonesimulator/Refine.app"
    BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
    xcrun simctl boot "$DEVICE" 2>/dev/null || true
    open -a Simulator
    xcrun simctl install "$DEVICE" "$APP"
    xcrun simctl launch "$DEVICE" "$BUNDLE_ID" >/dev/null
    echo "Running $BUNDLE_ID on $DEVICE."
    ;;
  --ipa)
    # Unsigned: SideStore signs it on the iPhone with your Apple ID.
    run_xcodebuild -configuration Release -destination "generic/platform=iOS" \
      CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
    APP="$DERIVED/Build/Products/Release-iphoneos/Refine.app"
    [ -d "$APP/PlugIns/RefineKeyboard.appex/js" ] || { echo "error: the keyboard has no bundled JS"; exit 1; }
    rm -rf build/ipa build/Refine.ipa
    mkdir -p build/ipa/Payload
    cp -R "$APP" build/ipa/Payload/
    (cd build/ipa && zip -qry ../Refine.ipa Payload)
    rm -rf build/ipa
    echo "Built build/Refine.ipa. AirDrop it to your iPhone and open it with SideStore."
    ;;
  "")
    open Refine.xcodeproj
    ;;
  *)
    echo "Usage: $0 [--sim | --ipa]"; exit 1
    ;;
esac
