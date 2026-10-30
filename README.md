# WatchLink — your own iPhone companion prototype

This is native SwiftUI + CoreBluetooth source code for an iPhone app. It is **not a signed IPA**, not a complete Samsung app replacement, and has **not been compiled or tested on an iPhone or Galaxy Watch** in the delivery environment.

Target device: Samsung Galaxy Watch SM-R800, Tizen 5.5.0.2, reported firmware R800XXU1GWE2. Deployment target: iOS 16 or later. Uses only Apple system frameworks; no package dependencies.

## What is implemented in the source

- Dark interface with a mint watch dashboard and a custom app icon.
- User-initiated 15-second Bluetooth LE search, plus retrieval of some already-connected peripherals and the last selected device.
- Explicit device selection, connection timeout, disconnect and error handling.
- Discovery of visible GATT services and characteristics.
- Reads the standard Battery Level characteristic when the selected device exposes it and permits access; otherwise shows an unavailable state, not a made-up number.
- Reads standard model, firmware and manufacturer fields when exposed.
- Shares a text capability report, excluding names, peripheral IDs and raw values.
- Clear status for features that are not implemented.

The current app does **not** synchronize health data, transfer photos/music, forward notifications, provide watch music controls, install watch apps or talk SDB. Existing notifications or controls supplied by Samsung/iOS pairing do not count as WatchLink features. Generic BLE access is not proof that Samsung's proprietary protocol is accessible.

## Windows: build through GitHub Actions

Apple's iOS toolchain runs on macOS. The included workflow lets you request that build from a browser on Windows. No Mac ownership is required for that route. GitHub account access and available Actions runner minutes are required; check your plan before running macOS jobs.

1. Unzip this project on Windows.
2. Create your own GitHub repository. Upload the **contents** of the `WatchLink` folder to its root. The repository root must contain `WatchLink.xcodeproj`, the `WatchLink` source folder, and `.github/workflows/build-ios.yml`. Check the workflow file was included: hidden folders are easy to omit when uploading.
3. Open **Actions → Build WatchLink unsigned IPA → Run workflow**. If the workflow is absent, ensure its YAML is on the repository's default branch.
4. A successful run exposes the **WatchLink-unsigned-IPA** artifact. Download and unzip that artifact to get `WatchLink-unsigned.ipa`.
5. The IPA must then be signed/provisioned for your iPhone using your existing trusted sideloading setup. Developer Mode alone does not sign or install it. You may need a unique bundle ID; the source currently uses `org.personal.watchlink`.

The workflow has not been run for you. Build success is not established until Xcode completes it. If it fails, provide the first compiler error from the build step. Do not provide Apple credentials or signing keys in chat, source code or public repositories.

## Mac alternative

Open `WatchLink.xcodeproj` in Xcode 16 or later. Select the WatchLink target, choose your own signing team, assign a unique bundle ID and select your physical iPhone. Build and run. A simulator cannot validate this watch connection.

## First real-device test

1. Keep your working Samsung pairing. Do not reset the watch or delete its installed apps.
2. Open WatchLink, choose **Find my watch** and allow Bluetooth permission.
3. Keep the watch awake. Select its name from the list; other nearby BLE devices may appear too. Do not assume a name proves the hardware identity.
4. WatchLink attempts its own CoreBluetooth connection. A watch listed as paired in iOS Settings is not guaranteed to be discoverable or accessible here. It may expose no standard battery service even while Samsung's app shows battery.
5. Open **Services → Share capability report**. Review and share that report if you want help extending the implementation. If discovery is still running, wait for completion or the timeout before exporting.
6. Try leaving the app, returning, disconnecting, reconnecting, and switching Bluetooth off/on. Confirm the dashboard never displays a stale battery value after disconnecting.

No data is uploaded automatically. This is a foreground prototype: it stops scanning when it leaves the foreground and does not claim background sync or persistent background connections. Only the last selected peripheral UUID is saved locally.

## Your own store and file format

See `CUSTOM_STORE.md`. A custom store can distribute our own content, but it cannot make the watch execute unsupported files. This prototype deliberately does not show a working store or install buttons for a capability we have not established.

## Verification and limitations

See `VALIDATION.md` for checks actually performed and the hardware/build checks still required. The service browser is an investigation tool, not a declaration of feature compatibility.

## Primary references

- Apple CoreBluetooth: https://developer.apple.com/documentation/corebluetooth/cbcentralmanager
- Apple Bluetooth privacy key: https://developer.apple.com/documentation/bundleresources/information-property-list/nsbluetoothalwaysusagedescription
- Samsung Accessory SDK overview: https://developer.samsung.com/galaxy-accessory/overview.html
- Samsung certificate FAQ: https://developer.samsung.com/galaxy-watch-tizen/getting-certificates/faq.html
- GitHub workflow syntax: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax

Independent project; not affiliated with Samsung or Apple.
