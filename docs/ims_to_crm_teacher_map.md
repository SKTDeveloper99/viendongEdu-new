# IMS → CRM mapping — teacher screens (bot A2)

Scope: `lib/screens/gv_home_screen.dart`, `gv_schedule_screen.dart`,
`gv_lophoc_screen.dart`, `gv_quanly_lop_screen.dart`,
`gv_user_list_screen.dart`, `gv_diemdanh_list_screen.dart`,
`gv_lichthi_screen.dart`, `gv_profile_info_screen.dart`,
`ems_attendance_teacher_screen.dart`.

New files: `lib/services/crm_teacher_api.dart`,
`lib/services/crm_session_guard.dart`, `lib/models/crm_teacher_profile.dart`,
`lib/models/crm_teacher_class.dart`.

## Screens that made NO IMS call (verified, left untouched)

- `gv_diemdanh_list_screen.dart` — entirely commented out, not imported by
  any router. Dead code, no `ApiService` reference.
- `gv_user_list_screen.dart` — not routed anywhere. Calls a third-party
  notification microservice (`noti-backend-eight.vercel.app`), not IMS/ApiService.
  Left as-is.

## Mapping table

| Screen | Old IMS call (`ApiService`) | CRM call (`CrmTeacherApi` / `EmsApiService`) | Gaps |
|---|---|---|---|
| `gv_home_screen` | `getGvScheduleByDate(date)` | `CrmTeacherApi.overview()` → `GET /api/teacher/me/overview` (today's sessions + profile + summary in one round trip) | — |
| `gv_home_screen` | `AppSession.instance.giangVien` (IMS model, **always null** since 6.1.0 — no login screen populates it any more) | `AppSession.instance.fullName` / `.teacherCode` (no network — already in the CRM session) for name/code; `CrmTeacherApi.overview().teacher.isCoHuu` (`teachers.type == 'gvch'`) for the "Cơ hữu" badge | Birth date has no CRM equivalent — see `gv_profile_info_screen` row |
| `gv_home_screen` | `AppSession.instance.giangVien?.id` used as `studentID` for the (non-IMS, non-CRM) noti-backend unread count | `AppSession.instance.teacherId` (CRM UUID) | This is a third-party notification service, not IMS/CRM. It previously used an IMS numeric id; now gets the CRM UUID — the best real identifier available in the session. Whether that service's schema accepts a UUID is unverified (outside CRM/IMS, out of this slice's scope). |
| `gv_schedule_screen` | `getGvScheduleByDate(date)` | `CrmTeacherApi.scheduleForDate(date)` → `GET /api/teacher/me/schedule?date=` | Field shapes are a 1:1 match (`mhten`, `phongten`, `lmhma`, `thoigianbd/kt`, `buoi`, `baonghiyn`) — no UI changes needed beyond the fetch call. |
| `gv_lophoc_screen` | `getHocKy()` | `CrmTeacherApi.semesters()` → `GET /api/teacher/me/semesters` | — |
| `gv_lophoc_screen` | `getGvTkbTheoHocKy(hockyid)` | `CrmTeacherApi.scheduleForSemester(semesterCode)` → `GET /api/teacher/me/schedule/semester?semester=` | Dedup key switched from `phongma` (IMS room code, no CRM equivalent) to `phongten` (room name) — same practical effect. |
| `gv_quanly_lop_screen` | `getHocKy()` | `CrmTeacherApi.semesters()` | — |
| `gv_quanly_lop_screen` | `getGvDanhSachLop(hockyid)` | `CrmTeacherApi.classes(semester:)` → `GET /api/teacher/me/classes?semester=` | **Section id is now a CRM UUID** (`sections.id`), not an IMS int `lopmonhocid`. Every screen/widget that stored `lop['id'] as int` now carries `CrmTeacherClass.sectionId` (String). No "% điểm chuyên cần/giữa kỳ/cuối kỳ" weighting in CRM (`sections`/`subjects` have no such column) — the old donut chart is dropped rather than showing invented numbers; flagged inline with a comment for a future bot/human pricing-style decision. |
| `gv_quanly_lop_screen` | `getGvDanhSachHocVien(lopId)` | `CrmTeacherApi.classStudents(sectionId)` → `GET /api/teacher/me/classes/:sectionId/students` | — |
| `gv_quanly_lop_screen` | `getGvDanhSachBuoiHoc(lopId)` + `getGvDanhSachTongHop(lopId)` (two calls) | `CrmTeacherApi.classAttendance(sectionId)` → `GET /api/teacher/me/classes/:sectionId/attendance` (one call, flat rows) | CRM returns one flat row per (session × student) instead of two pre-aggregated IMS endpoints. The screen now groups by `session_id` for "Buổi học" and aggregates by `mssv` for "Tổng hợp" client-side. These CRM numbers come from CRM's own `attendance` table (a snapshot/import), **not EMS** — same trust level the old IMS numbers had. EMS (`attendance_marks`, the real write path) is still consulted per due session via `EmsApiService.sessionMarks` for the actual có mặt/vắng truth, unchanged in spirit from the pre-cutover code. |
| `gv_quanly_lop_screen` | `postDiemDanhDanhSach(...)` (IMS roster for one buổi) | `CrmAttendanceRow` rows already grouped client-side (see above); no separate per-buổi IMS call needed | `EmsApiService.sessionKeyFor(lmhId:...)` still needs the IMS `lop_mon_hoc_id` (`lmhid`) to build a `session_key` — that id is DATA synced into CRM (`sections.ims_lop_mon_hoc_id`), not a live IMS call. CRM's `/me/classes` and `/me/classes/:id/attendance` do **not** expose it, so the screen additionally fetches `GET /me/schedule/semester` once per semester load and joins on `lmhma == section_code` to build a `sectionCode → lmhid` map. If a class's `lmhid` can't be resolved this way (e.g. no matching schedule slot), the "Điểm danh" tab shows a banner and falls back to CRM-only counts instead of guessing. |
| `gv_lichthi_screen` | `getGvLichThi(ngayBatDau, ngayKetThuc)` + `getGvDanhSachLop(hockyid)` (joined client-side to filter to the teacher's own classes and pull subject name) | `CrmTeacherApi.exams(semester:)` → `GET /api/teacher/me/exams?semester=` | **Dependency not yet on `main`/prod** as of 2026-09-24/25: this route (`routes/portals/teacher-exams.js`, bot S3) exists only on a separate working branch in the crm-clean repo (worktree `agent-a86dcd5eb8ad283d1`), not yet merged. Calling it before that merge returns 404 — handled like any other network error (shows "Thử lại"), no app-side change needed once it lands. Server-side scoping (by the teacher's own `ims_id`) replaces the old client-side join against `getGvDanhSachLop`, so that extra call is gone. Room is frequently `null` (IMS data quality, not a join bug) — shown as empty per "no equivalent field, don't invent". **Semester param contract**: per the coordinator's 2026-09-25 note, the server is being changed so that `GET /api/teacher/me/exams` with no `semester` returns full history and `?semester=<code>` filters to one semester (currently, no param defaults to only the current semester). This screen always passes `semester` explicitly for whichever semester the teacher has selected in the dropdown — it never calls `exams()` with no param — so it is already correct under both the old and the new server behavior. |
| `gv_profile_info_screen` | `GiangVien gv` (IMS model passed in by the caller — **always null** since 6.1.0) + `userid` (IMS field, also stale) | `CrmTeacherProfile? profile` (from `CrmTeacherApi.overview().teacher`) + `fallbackName`/`teacherCode` from `AppSession` (works even before the network call resolves) | `teachers` (CRM) has no birth-date column — IMS `GiangVien.ngaysinh` has no CRM equivalent. The "Ngày sinh" row is dropped rather than invented; documented inline in the screen with a TODO note for if/when CRM adds it. No edit button exists on this screen, so no `TODO(A4)` was needed. |
| `ems_attendance_teacher_screen` | (none — already CRM/EMS-only before this slice) | `EmsApiService.mySessions/roster/saveMarks` (unchanged) | Verified via `grep` and the existing `ems_purge_guard_test.dart` regression test (passes). |

## `lib/services/crm_session_guard.dart`

Small shared helper, `Future<bool> handleCrmAuthError(BuildContext, Object)`:
on an `EmsException` with `statusCode == 401`, clears `AppSession` and
navigates to `/login`, returning `true` so the calling `catch` block can skip
its normal error UI. Every fetch added in this slice calls it first in its
`catch`. Intentionally trivial — another bot in the same IMS-removal effort
may add an identical helper elsewhere; this one only touches the teacher
screens' own `catch` blocks.

## Verification

- `grep -n "ApiService\." lib/screens/gv_*.dart lib/screens/ems_attendance_teacher_screen.dart` → only `EmsApiService.*` matches (and one comment mentioning the old IMS call by name for context).
- `grep -n "import.*api_service.dart'" ...` (the IMS one, not `ems_api_service.dart`) → no matches in any of the nine screens.
- `test/ems_purge_guard_test.dart` (pre-existing regression suite, not written by this bot) passes unchanged, including its teacher-scoped assertions ("teacher Quản lý lớp session detail reads EMS session-marks", "no screen calls the IMS attendance write endpoint").
