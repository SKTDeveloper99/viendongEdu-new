# Crashlytics

## What was added
- `firebase_crashlytics` (pinned to 5.3.0: it must use the same firebase-ios-sdk, 12.18.0, as `firebase_messaging` 16.6.0; 5.4.0 breaks iOS SwiftPM resolution. Bump both together).
- `lib/main.dart`: after `Firebase.initializeApp`, Flutter and platform errors are reported as fatal. Collection is off in debug builds. Wrapped in try/catch, so Crashlytics can never block app start.
- Android: Gradle plugin `com.google.firebase.crashlytics` 3.0.6 (`android/settings.gradle.kts`, `android/app/build.gradle.kts`).
- iOS: Run Script phase "Upload Crashlytics dSYMs" in the Runner target (uses the SwiftPM checkout of firebase-ios-sdk; warns and skips if not found).

## Where to see crashes
Firebase console -> project -> Release & Monitor -> Crashlytics. Reports appear after the app is relaunched following a crash.

## Privacy rule (users include minors)
Never call `setUserIdentifier`, `setCustomKey` or `log` with MSSV, names, phone numbers, tokens or request bodies. Crash stack traces only.

## Force a test crash (never ship it)
Collection is disabled in debug, so test in a profile/release build on a device, using a temporary local edit that you do NOT commit: add `FirebaseCrashlytics.instance.crash();` to a button's `onPressed`, run `flutter run --release`, tap it, relaunch the app, and check the console (a few minutes). Revert the edit afterwards.

## iOS dSYM phase (if it ever needs redoing by hand)
Xcode -> Runner target -> Build Phases -> + -> New Run Script Phase, placed last. Script: `"${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"`. Input files: `${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}` and `$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)`.
Note: the phase was only build-tested with `flutter build ios --debug`; confirm dSYM upload once on a real archive (Xcode Organizer build log / Crashlytics console "missing dSYM" banner).
