# Codex mobile run actions

This repo does not currently use a dedicated Codex action manifest. The simplest setup is to register Codex run actions that call the shared script below:

```bash
sh mobile/scripts/codex-mobile-action.sh <action>
```

The script keeps the command surface stable, so Codex actions can stay short even if the Flutter flags change later.

## Recommended Codex actions

Register these commands in Codex for this workspace:

| Action name | Command |
| --- | --- |
| Flutter pub get | `sh mobile/scripts/codex-mobile-action.sh pub-get` |
| Android build APK | `sh mobile/scripts/codex-mobile-action.sh build-android-apk` |
| Android build AAB | `sh mobile/scripts/codex-mobile-action.sh build-android-aab` |
| Android deploy to device | `ANDROID_DEVICE_ID=<device-id> sh mobile/scripts/codex-mobile-action.sh deploy-android` |
| iOS build (no codesign) | `sh mobile/scripts/codex-mobile-action.sh build-ios` |
| iOS build IPA | `IOS_EXPORT_OPTIONS_PLIST=ios/ExportOptions.plist sh mobile/scripts/codex-mobile-action.sh build-ios-ipa` |
| iOS deploy to device | `IOS_DEVICE_ID=<device-id> sh mobile/scripts/codex-mobile-action.sh deploy-ios` |

## Environment variables

All actions support:

- `API_BASE_URL`
  backend URL passed to Flutter as `--dart-define=API_BASE_URL=...`
- `FLUTTER_BUILD_FLAVOR`
  optional Flutter flavor if you introduce flavors later
- `FLUTTER_BUILD_NAME`
  optional app version passed to Flutter as `--build-name=...`
- `FLUTTER_BUILD_NUMBER`
  optional build number passed to Flutter as `--build-number=...`

Extra variables for deploy/export actions:

- `ANDROID_DEVICE_ID`
  required by `deploy-android`
- `IOS_DEVICE_ID`
  required by `deploy-ios`
- `IOS_EXPORT_OPTIONS_PLIST`
  required by `build-ios-ipa`

If `API_BASE_URL` is not set, the script defaults to `http://100.113.187.63` to match the current README examples.

## Notes by platform

### Android

- `build-android-apk` creates `mobile/build/app/outputs/flutter-apk/app-release.apk`
- `build-android-aab` creates `mobile/build/app/outputs/bundle/release/app-release.aab`
- release signing uses `mobile/android/key.properties` when present

### iOS

- `build-ios` uses `--no-codesign`, which is the safest default for a shared Codex action
- `build-ios-ipa` requires valid signing in Xcode plus an export options plist
- `deploy-ios` expects a connected simulator or physical device already visible to Flutter
- plain HTTP backends are usually not suitable for physical iPhone installs because of ATS; prefer the HTTPS/Tailscale endpoint there

## Example commands

```bash
API_BASE_URL=https://twoj-host.tailnet.ts.net \
sh mobile/scripts/codex-mobile-action.sh build-android-apk
```

Przykład dla GitHub Actions z automatycznym numerem buildu:

```bash
API_BASE_URL=https://twoj-host.tailnet.ts.net \
FLUTTER_BUILD_NUMBER="$GITHUB_RUN_NUMBER" \
sh mobile/scripts/codex-mobile-action.sh build-android-apk
```

```bash
API_BASE_URL=https://twoj-host.tailnet.ts.net \
ANDROID_DEVICE_ID=R5CX123456A \
sh mobile/scripts/codex-mobile-action.sh deploy-android
```

```bash
API_BASE_URL=https://twoj-host.tailnet.ts.net \
IOS_DEVICE_ID=00008110-001234560E12801E \
sh mobile/scripts/codex-mobile-action.sh deploy-ios
```
