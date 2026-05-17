#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
MOBILE_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter is required but not installed or not on PATH." >&2
  exit 1
fi

ACTION=${1:-}

API_BASE_URL=${API_BASE_URL:-http://besztia.tail218f8.ts.net:8080}
FLUTTER_BUILD_FLAVOR=${FLUTTER_BUILD_FLAVOR:-}
FLUTTER_BUILD_NAME=${FLUTTER_BUILD_NAME:-}
FLUTTER_BUILD_NUMBER=${FLUTTER_BUILD_NUMBER:-}
ANDROID_DEVICE_ID=${ANDROID_DEVICE_ID:-}
IOS_DEVICE_ID=${IOS_DEVICE_ID:-}
IOS_EXPORT_OPTIONS_PLIST=${IOS_EXPORT_OPTIONS_PLIST:-}

cd "$MOBILE_DIR"

run_flutter() {
  set -- flutter "$@"

  if [ -n "$FLUTTER_BUILD_FLAVOR" ]; then
    set -- "$@" --flavor "$FLUTTER_BUILD_FLAVOR"
  fi

  if [ -n "$FLUTTER_BUILD_NAME" ]; then
    set -- "$@" "--build-name=$FLUTTER_BUILD_NAME"
  fi

  if [ -n "$FLUTTER_BUILD_NUMBER" ]; then
    set -- "$@" "--build-number=$FLUTTER_BUILD_NUMBER"
  fi

  set -- "$@" "--dart-define=API_BASE_URL=$API_BASE_URL"

  "$@"
}

require_value() {
  value=$1
  name=$2

  if [ -z "$value" ]; then
    echo "$name is required for this action." >&2
    exit 1
  fi
}

print_usage() {
  cat <<'EOF'
Usage:
  sh mobile/scripts/codex-mobile-action.sh <action>

Actions:
  pub-get
  build-android-apk
  build-android-aab
  deploy-android
  build-ios
  build-ios-ipa
  deploy-ios

Environment:
  API_BASE_URL               Backend URL passed through --dart-define.
  FLUTTER_BUILD_FLAVOR       Optional Flutter flavor name.
  FLUTTER_BUILD_NAME         Optional app version, for example 0.2.0.
  FLUTTER_BUILD_NUMBER       Optional build number, for example 58.
  ANDROID_DEVICE_ID          Required by deploy-android.
  IOS_DEVICE_ID              Required by deploy-ios.
  IOS_EXPORT_OPTIONS_PLIST   Required by build-ios-ipa.
EOF
}

case "$ACTION" in
  pub-get)
    flutter pub get
    ;;
  build-android-apk)
    flutter pub get
    run_flutter build apk --release
    ;;
  build-android-aab)
    flutter pub get
    run_flutter build appbundle --release
    ;;
  deploy-android)
    require_value "$ANDROID_DEVICE_ID" "ANDROID_DEVICE_ID"
    flutter pub get
    run_flutter run --release -d "$ANDROID_DEVICE_ID"
    ;;
  build-ios)
    flutter pub get
    run_flutter build ios --release --no-codesign
    ;;
  build-ios-ipa)
    require_value "$IOS_EXPORT_OPTIONS_PLIST" "IOS_EXPORT_OPTIONS_PLIST"
    flutter pub get
    run_flutter build ipa --release --export-options-plist="$IOS_EXPORT_OPTIONS_PLIST"
    ;;
  deploy-ios)
    require_value "$IOS_DEVICE_ID" "IOS_DEVICE_ID"
    flutter pub get
    run_flutter run --release -d "$IOS_DEVICE_ID"
    ;;
  ""|-h|--help|help)
    print_usage
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    print_usage >&2
    exit 1
    ;;
esac
