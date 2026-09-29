# Unified Viễn Đông app: integration and release status

**Built 2026-09-29 from `main` (`f38222f`) on `codex/unified-school-app`.** One Flutter package contains both student and teacher routes, both authenticated directly against the CRM/EMS HTTPS API. The old IMS client is not used by the current route graph. No store or server deployment is part of this branch.

## Included

- Shared warm school theme in `lib/theme/vd_theme.dart`, with Be Vietnam Pro font, updated home cards and a lightweight splash. The native Android/iOS launch art is from the splash prototype. Colors, type, card radius, and mark can be adjusted in this one package.
- Teacher "Ngày làm việc của tôi": sessions, attendance entry, assigned student cases, and case answers. The case route requires the CRM `STUDENT_CASES_V1_ENABLED` feature and the teacher's server permission.
- Student "Hỏi nhà trường": server supplied destinations, conversation list/detail, replies, and local drafts. Drafts are never labeled sent until the server confirms. A failed/ambiguous send asks the student to check the conversation before retrying.
- Account scoped local snapshots for today's teacher overview, student schedule, and questions. The UI labels old data with its save time. Attendance roster and draft keys are now account scoped; on a restored session, legacy queued drafts are migrated. A server mark that conflicts with an offline mark stops automatic replay and asks the teacher to review.

## Configure and build

- Server URL: `lib/services/ems_api_service.dart` uses `EMS_API_BASE_URL`, default `https://ems.viendong.edu.vn/api`. Build with `--dart-define=EMS_API_BASE_URL=https://your-host/api` for a test server.
- Theme: edit `VdColors` and `VdTheme` in `lib/theme/vd_theme.dart`; keep contrast and large Vietnamese text readable. The splash image is `assets/logo2.png` and native launch marks are in Android drawable folders and iOS `LaunchImage.imageset`.
- `flutter pub get`, `flutter test`, `flutter analyze`, then `flutter build apk --release`. Test signed Android and iOS packages separately before submission. The version in `pubspec.yaml` must advance for each store release.

## Remaining release gates

| Gate | Current state and action |
|---|---|
| Offline reads | Home and questions have dated snapshots; other academic and finance screens still need deliberate offline behavior. Do not present a cached tuition or grade as live truth. |
| Offline attendance | Drafts persist and retry while the roster screen is open or resumed; global outbox draining after app restart is not implemented. A lost response still depends on read-back. Add server operation IDs, version checks, and a global queue before claiming no lost/duplicate writes. |
| Questions | Server has student-scoped auth and rate limits, but conversation create and reply endpoints do not accept an idempotency key. A timeout can leave delivery uncertain, so automatic retry is disabled. Assign PĐT, finance, faculty, and teacher owners; prove answer times and escalation before opening to all students. |
| Launch under no network | The minimum-version check now times out after two seconds before session restore. Measure cold start on low-end Vietnam phones and add a server-side version guard for old clients before relying on a shorter timeout. |
| Capacity | No 7 a.m. login/attendance/question/broadcast load test or Vietnam mobile-network test was possible locally. Measure p95/p99 API latency, DB pool wait, FCM queue lag, and app frame timing under a representative school peak. |
| Credentials and privacy | Existing CRM tokens and local snapshots use SharedPreferences. Move tokens and sensitive message drafts to platform secure storage before school-wide rollout; verify backup and logout behavior on shared devices. |
| Server contracts | Confirm live `/api/student/conversations/*` and `/api/student-cases/my-open*` permission and feature flags against the production server. Registration/profile writes remain EMS-recorded and need school ownership rules where IMS still holds downstream records. |
| App stores | Validate package IDs, signing, device matrix, crash telemetry, staged rollout and rollback paths. No app-store release was made here. |

The repository calendar seed puts HK262 at **2027-01-05** but also puts HK261 through **2027-01-30**, an overlap. Treat January 5 as a planning deadline until PĐT confirms the live calendar. Target a fully observed rollout by **2026-12-21**, leaving a correction window before that seeded date. Hold expansion whenever any gate fails.

Superseded prototype source and Git histories were preserved outside the app repository at `/Users/khoatran/Desktop/viendongedu-retired-20260929/`. Generated build caches were intentionally excluded.
