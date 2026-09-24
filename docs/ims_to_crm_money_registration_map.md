# IMS → CRM map — money, registration, profile (bot A4)

Every `ApiService` (IMS, `lib/services/api_service.dart`) call this slice
(`tuition_screen.dart`, `lephi_screen.dart`, `capbu_screen.dart`,
`registration_screen.dart`, new `profile_edit_screen.dart`) used to make,
and what replaces it. Server contracts read from the CRM repo
(`/Users/khoatran/Desktop/crm-clean`), not guessed:
`docs/api/mobile-ims-replacement-S3.md` (reads: exams/registration),
`S4.md` (fees/cấp bù/tuition mapping), `S5.md` (registration writes +
profile).

| Old `ApiService` call | Old IMS endpoint | New CRM call | New endpoint |
|---|---|---|---|
| `getTuition()` | `hocvien/hocphi` | `CrmMoneyApi.getTuition()` + `CrmMoneyApi.getCongNo()` | `GET /api/student/me/tuition`, `GET /api/student/me/cong-no` |
| `getLePhi()` | `hocvien/lephi` | `CrmMoneyApi.getFees()` | `GET /api/student/me/fees` |
| `getCapBu()` | `hocvien/capbu` | `CrmMoneyApi.getCapBu()` | `GET /api/student/me/capbu` |
| `getHocKy()` (used by registration for the semester dropdown) | `hocvien/hocky` (implicit, via `_get`) | `CrmRegistrationApi.getPeriods()` | `GET /api/student/me/registration/periods?semester=` (periods now carry their own `semester_code`/`semester_name`; no separate semester-list call needed) |
| `getDotDangKy(hockyid)` | `hocvien/dotdangky` | `CrmRegistrationApi.getPeriods()` | `GET /api/student/me/registration/periods?semester=` — one call returns period + its `is_open` (server-computed, not client-computed from `ngayBatDau`/`ngayKetThuc` any more) |
| `getMonHocDuKien(hockyid)` | `hocvien/monhocdukien` | `CrmRegistrationApi.getOfferings(periodId:, allSections:)` | `GET /api/student/me/registration/offerings?period_id=&scope=` |
| `getKetQuaDangKy(hockyid)` | `hocvien/ketquadk` | `CrmRegistrationApi.getResults(semester:)` | `GET /api/student/me/registration/results?semester=` |
| `postDangKyMon(...)` | `hocvien/dangky` (POST) | `CrmRegistrationApi.register(offeringId)` | `POST /api/student/me/registration {offering_id}` |
| `deleteDangKyMon(...)` | `hocvien/dangky` (DELETE) | `CrmRegistrationApi.cancel(id)` | `DELETE /api/student/me/registration/:id` |
| `updateUserInfo(...)` | `user/info/update` | `CrmProfileApi.updateStudentProfile(...)` / `updateTeacherProfile(...)` | `PATCH /api/student/me/profile`, `PATCH /api/teacher/me/profile` |
| *(new — no IMS predecessor screen wired it)* | — | `CrmProfileApi.getStudentMe()` / `getTeacherMe()` | `GET /api/student/me`, `GET /api/teacher/me` — used only to pre-fill `profile_edit_screen.dart` |

## Field-identity changes (breaking, by design)

- **`offering_id` is no longer `mhid`/`monhocid`.** The old app registered by
  `hocvienid/dotdkid/monhocid/hockyid`. The new `offering_id` is
  `ims_snapshot.tbl_qldt_tkb_lopmonhoc.id` (LMH — a scheduled *section*, not
  a subject). One subject can have several LMH offerings (different
  sections/teachers); the old "one monhocid = one registration" model no
  longer applies. This is S5's own documented assumption about S3's
  `offering_id`, confirmed consistent between the read (S3) and write (S5)
  contracts as shipped.
- **`is_open` is server-computed**, not derived client-side from
  `ngayBatDau`/`ngayKetThuc` any more.
- **Registration results are a union of two sources**, `source:
  'ems_request'` (this app's own submissions, not yet synced to IMS) and
  `source: 'ims_roster'` (already on the IMS class roster). The old
  `ketquadk` endpoint had no such distinction — the CRM version is honest
  about which system actually knows about a registration.
- **Offerings are curriculum-filtered by default** (added mid-build,
  2026-09-25): `GET .../offerings` without `scope=` returns only sections in
  the student's own curriculum that they have not passed, with
  `in_my_curriculum` per row and a top-level `curriculum_resolved` flag
  (`false` = server could not resolve the student's curriculum and fell back
  to the unfiltered list — the app must say so, not present it as "your
  courses"). `scope=all` returns every open section; wired as the "Xem tất
  cả lớp" toggle on `registration_screen.dart`.
- **Tuition summary is pre-computed, not re-summed.** The old
  `TuitionItem._totalPaid/_totalDebt/_remaining` summed raw `soTien` signs
  client-side — this was BUG 2 in the CRM codebase (type-blind summing that
  double-counts lệ phí/miễn-giảm as tuition; see
  `test/student_portal_money_truth.test.js` in the CRM repo). The new
  `CrmTuitionSummary` is read verbatim from `summary.owedTotal/paid/balance`
  — never recomputed here.

## Known gaps (flagged, not invented — money law: never default a missing figure to 0/"")

- `ptma` (IMS phiếu-thu code) and `hkten` (semester display name) are not
  mirrored into `public.tuition_payments`, so `/me/tuition`, `/me/fees`
  cannot return them. `CrmTuitionPayment`/`CrmFeeItem` show `semesterCode`
  (machine code, e.g. `"261"`) where the old app showed a semester name —
  this is a display gap in the CRM sync layer, not something this slice can
  fix from the client.
- `GET /api/student/me` does **not** currently return `cccd`/`cmnd` (only
  `mssv, full_name, email, phone, ...` — see
  `repositories/portals-student-portal-repo.js getStudent`). The CMND/CCCD
  field on `profile_edit_screen.dart` therefore pre-fills empty for
  students even if a value exists in the database; a PATCH still writes it
  correctly, and the field is fully readable back afterwards from the PATCH
  response only (not from a subsequent GET, until the GET endpoint is
  extended server-side). Not invented — left visibly empty.
- Cấp bù has no CRM pricing law (`/me/capbu` is a read-only IMS mirror);
  `vat` is frequently `null` in the source data — passed through as-is.
- `EmsApiService.send()` does not support `PATCH` (only GET/POST/DELETE).
  Per this slice's brief, `ems_api_service.dart` could not be edited, so
  `CrmProfileApi` implements its own minimal PATCH call reusing
  `EmsApiService.client`/`baseUrl` (so tests can still swap the client) and
  a local `EmsException`-compatible error decode. If another bot needs
  PATCH too, this logic is a candidate to hoist into `EmsApiService` itself
  in a later pass — flagged here rather than duplicated silently.
