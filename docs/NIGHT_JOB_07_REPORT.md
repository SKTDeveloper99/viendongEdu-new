# Night Job 07 — app review findings and home tests

Completed on `night/app-guard-colours` using Flutter 3.47.4 / Dart 3.13.3.
Read CRM `AGENTS.md` first, then read the two app sections of
`origin/night/review:NIGHT_REVIEW_2026-10-22.md` with `git show` in the CRM clone.

## Review disposition and changes

- The colour-literal architecture failure described under `night/app-analyze`
  is already fixed here by `8217be1` (announcement palette extraction). The
  review found no palette regression or additional applicable source issue.
  The full suite below confirms the palette tests and unchanged architecture
  guard pass. No allowlist or analyzer rule was relaxed.
- Reproduced the three reported home failures before editing: **5 passed,
  3 failed**, each finding two morning-subject labels.
- These duplicates are intentional. `DashboardTab` renders a `NextUpCard`
  for the current/next class plus `TodaySchedule`, whose `ClassChip` list
  includes that same class. The three tests mean to check that the schedule
  survives a board error, intentional EMS denial, or a failed refresh with a
  stored schedule. Their assertions now require exactly one matching label
  within `ClassChip`, following the existing successful home test.
- Injected the existing view model clock at fictional fixture time
  2026-10-22 07:00, with matching fixture weekday, disabled clock ticks and
  explicit view model disposal. The tests always exercise the duplicate-label
  case regardless of the runner's date or hour; HTTP and stored-copy paths
  still use the real repository with the existing mock HTTP client.
- Strengthened the first home test to require two schedule cards and a
  separate matching next-class card. Collapsing the schedule removes its
  cards while preserving the next-class subject. No test was deleted or
  skipped; production widgets were unchanged.

Implementation commit: `90868fb` — Fix student home schedule finders and freeze
the test clock.

## Checks

- `dart format --output=none --set-exit-if-changed test/student_home_screen_test.dart`:
  **exit 0**, no formatting changes needed.
- `flutter test --no-pub test/student_home_screen_test.dart --reporter expanded`:
  **exit 0; 8 passed, 0 failed, 0 skipped**.
- `flutter test --no-pub --reporter expanded`:
  **exit 0; 556 passed, 0 failed, 0 skipped**, including goldens, announcement
  palette and architecture guards. Local log: `.git/night-job-07-flutter-test.log`.
- `flutter analyze --no-pub`: **exit 0; no issues found**.
- `git diff --check`: **passed**.

## Limits and owner decisions

No owner decision is needed to complete this job. The reasonable unattended
choice was to keep the deliberate next-class summary and make schedule
assertions precise. Fixtures remain fictional; no production data or `.env`
file was read. No dependency, version, law, security or production-system
changes were made. No build, deployment, remote restart or push was performed.
Device rendering and platform builds remain unverified; the full widget and
golden suite passed locally. Work is committed locally for the runner to push.
