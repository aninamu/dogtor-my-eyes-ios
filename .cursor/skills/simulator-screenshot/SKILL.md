---
name: simulator-screenshot
description: >-
  Builds Dogtor My Eyes, boots the iPhone 17 simulator, launches the app, and
  captures a screenshot into artifacts/. Use when the user asks for a simulator
  screenshot, UI capture, or visual proof of a screen.
---

# Simulator screenshot

Requires macOS with Xcode. Output goes under `artifacts/` (gitignored).

## Steps

1. Create the output directory:

```bash
mkdir -p artifacts
```

2. Build for the simulator:

```bash
xcodebuild \
  -scheme DogtorMyEyes \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath build \
  build
```

3. Boot and open Simulator (idempotent):

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
open -a Simulator
```

4. Install and launch. Resolve the `.app` path from DerivedData:

```bash
APP=$(find build/Build/Products -name 'DogtorMyEyes.app' -type d | head -1)
xcrun simctl install booted "$APP"
xcrun simctl launch booted com.dogtormyeyes.DogtorMyEyes || \
  xcrun simctl launch booted "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
```

If the bundle id lookup fails, read it from the Xcode project / built Info.plist and use that.

5. Wait ~2s for first frame, then capture:

```bash
xcrun simctl io booted screenshot "artifacts/dogtor-$(date +%Y%m%d-%H%M%S).png"
```

6. Report the screenshot path to the user. Do not commit `artifacts/`.

## Notes

- Prefer `iPhone 17` to match README / CI destination.
- If build fails, stop and surface the `xcodebuild` error — do not screenshot a stale install.
- For a specific screen (detail, favorites), say so in the chat so the agent can navigate before capturing; this skill only guarantees launch + home/browse frame unless guided further.
