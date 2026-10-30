# Validation record

Date: 2026-10-30

## Completed

- Parsed generated OpenStep Xcode project syntax and checked object references.
- Checked that all referenced source/resource paths exist.
- Parsed the shared scheme and checked its target references.
- Parsed the Info.plist, confirmed a Bluetooth purpose string and no background-mode claim.
- Parsed the GitHub Actions workflow and confirmed manual invocation.
- Parsed asset catalogs and verified referenced icon files exist.
- Checked that the Bluetooth implementation does not call characteristic write operations.
- Checked that the exported report excludes the name-bearing session status, device name and peripheral UUID.
- Manually reviewed scan/connection timeouts, permission states, disconnect cleanup, standard-field read allowlist and battery-value validation.

## Not completed

This Linux environment has no Swift compiler, Apple iOS SDK, Xcode, signing identity or physical access to the watch/iPhone. Swift compilation, UI rendering, IPA generation, installation and all actual Bluetooth behavior remain unverified. Structural checks are not a substitute for an Xcode build or hardware tests.

## Required acceptance tests

1. Run the included macOS build workflow; resolve any compiler or asset errors before signing.
2. Install a signed build on a real iPhone. Check initial Bluetooth permission allow/deny paths.
3. Scan with watch awake and already paired; distinguish the chosen device from unrelated BLE peripherals.
4. Verify timeout if a remembered device is unavailable.
5. Discover real services and export a report after discovery completes. If no standard battery service is exposed, the UI must report unavailability rather than a percentage.
6. If battery data is available, compare with Samsung's own reading and exercise refresh.
7. Disconnect, toggle Bluetooth, and reconnect; confirm stale readings are cleared.
8. Review report contents before sharing. No cloud upload should occur without the share action.
9. Confirm that existing Samsung/iOS notification or media functionality is not represented as functionality implemented by WatchLink.

Do not remove the working Samsung app/pairing as an acceptance prerequisite. Full independence has not been established.
