# Job 04: safe Flutter analyzer cleanup

Date: 2026-10-22. Branch: `night/app-analyze`.
Starting commit: `265fe64`.
Toolchain: Flutter 3.47.4 stable, Dart 3.13.3, on the owner's Mac.

## Outcome

No source changes were necessary: the configured analyzer already reports
zero issues. This report is the only committed change. There are no issue-type
fix groups to commit, and no analyzer findings were skipped.

## Checks

| Command | Before | After |
| --- | --- | --- |
| `flutter analyze` | Exit 0; 0 issues | Exit 0; 0 issues |
| `flutter test` | Exit 1; 544 passed, 4 failed | Exit 1; 544 passed, same 4 failed |

Both test runs failed in exactly these existing cases:

- `test/architecture_guard_test.dart`: `colours come from context.vd tokens,
  not literals (shrink-only)`. The guard reports 19 colour literals in
  `lib/components/announcement_body.dart`, with 0 allowed.
- `test/student_home_screen_test.dart:221`: board failure still shows retry
  while the schedule works.
- `test/student_home_screen_test.dart:235`: intentional EMS rejection does
  not show retry.
- `test/student_home_screen_test.dart:264`: failed schedule uses its saved
  copy and shows `StaleNote`.

All three student-home failures expected exactly one matching widget for the
fictional morning subject text but found two. These additional failures were
present before any change and reproduced in the final run.

`git diff --check` passed for the report.

## Skipped work and decisions

- Left the known architecture failure unchanged: the job explicitly excludes
  `lib/components/announcement_body.dart`; altering the guard would weaken it.
- Left the three pre-existing student-home test failures unchanged: changing
  widget behavior or test expectations is outside analyzer-only cleanup.
- Did not enable extra lint rules, remove suppressions, or perform speculative
  cleanup in the absence of analyzer findings.
- Dependency update notices were informational; no dependencies, lockfile,
  versions, build files, or analyzer settings were changed.

The suite remains as green as the measured baseline, but is not fully green.
Runtime behavior on a device is unverified; no device build was needed for
this documentation-only outcome. No production access, deployment, push, or
history rewrite was performed. Owner follow-up: investigate the existing
student-home expectations and resolve the announcement guard in their own
scope. No owner decision is required to complete Job 04.
