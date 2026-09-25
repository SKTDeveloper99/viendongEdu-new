# IMS → CRM map — student academic screens (bot A3)

Scope: `lib/screens/hv_home_screen.dart`, `schedule_screen.dart`,
`classes_screen.dart`, `grades_screen.dart`, `exam_screen.dart`,
`hv_profile_info_screen.dart`, `student_board_screen.dart` (already CRM-only),
`ems_attendance_student_screen.dart` (already CRM-only). New files:
`lib/services/crm_student_api.dart`, `lib/models/crm_student_profile.dart`,
`lib/models/crm_student_grades.dart`, `lib/models/crm_student_schedule.dart`,
`lib/models/crm_student_exams.dart`, `lib/models/crm_student_graduation_summary.dart`,
`lib/services/crm_session_guard.dart`.

**2026-09-25 review update (A3 coordinator, real server shapes checked
against student 2447092028):** three corrections below, each marked
**[2026-09-25]**.

Server contracts were read from `/Users/khoatran/Desktop/crm-clean` (routes,
lib, repositories) and from the exam-endpoint doc in that repo's worktree
`.claude/worktrees/agent-a86dcd5eb8ad283d1/docs/api/mobile-ims-replacement-S3.md`.
Nothing below is guessed from naming conventions alone.

## Call map

| Old IMS call (`api_service.dart`) | CRM endpoint | Screen(s) | Gap / behaviour change |
|---|---|---|---|
| `hocvien/user/info` (`getUserInfo`) | `GET /api/student/me` | hv_profile_info_screen, hv_home_screen (header) | `students.cccd` exists in the DB but the portal's `getStudent()` SELECT does not return it — CCCD shown as "—". CRM has one ngành level only; "chuyên ngành" shown as "—". |
| `hocvien/tkbtheongay?ngay=` (`getScheduleByDate`, `getTodaySchedule`) | `GET /api/student/me/schedule?semester=` | schedule_screen, hv_home_screen (today card) | IMS was per-DAY; CRM is per-SEMESTER, weekly-recurring (day_code + start/end time + `weeks_pattern`/`tuanhocstr`, undocumented encoding, kept on the model but never decoded). A date is matched client-side by weekday + `[start_date, end_date]` (`CrmScheduleItem.occursOn`) — a class that meets on alternating weeks may over-show on some dates, since `weeks_pattern` is not decoded. `buoi` (sáng/chiều/tối) no longer exists server-side; derived client-side from the start hour. `loaitkb == 'lichthi'` (exam rows mixed into the day feed) has no equivalent — exams are a separate endpoint/screen now. `baonghiyn` (báo nghỉ flag on the schedule row) has no CRM equivalent; the EMS-attendance-mark lookup is the only source of "excused" now. **[2026-09-25]** `start_date`/`end_date` are treated as CALENDAR dates, never moments: `_calendarDate()` takes only the Y-M-D of `DateTime.parse(s).toUtc()` and re-anchors it at UTC midnight, discarding both the server's own zone (Melbourne on the reviewer's local box, UTC on prod) and the phone's local zone. `occursOn(date)` re-derives `date`'s own Y-M-D the same way before comparing — it never calls `.toLocal()`, so a UTC-midnight boundary can't drift onto the wrong calendar day regardless of which timezone the phone or the server is in. |
| `hocvien/lopmonhoc?hockyid=` (`getLopMonHoc`) | `GET /api/student/me/sections?semester=` | classes_screen | No per-class evaluation weights (`tylecc`/`tylegk`/`tyleck`) or syllabus text (`decuong`) on the CRM side — these were already dead/unused in the old screen's widget tree, so nothing user-visible regresses. No `diemcc` (chuyên cần) score exists; only midterm (`diemgk`) and final-exam (`diemck`) come from `/me/grades`, matched by `section_code` (falling back to subject_code+semester for hand-entered grade rows with no LMH). No `lmhid` (IMS surrogate key) any more — EMS attendance for a class is now matched by `section_code`, not an id prefix. |
| `hocky` (`getHocKy`) | **no student endpoint** | classes_screen, exam_screen | CRM has `GET /api/teacher/me/semesters` (teacher-only — verified by reading `routes/portals/teacher-portal.js`); there is no student equivalent. The semester list is DERIVED from distinct `semester_code` values in `/me/sections`, labelled by `semesterCodeLabel()` (a client-side formula: 2-digit year + 1-digit semester, matching the one confirmed real sample in the exams doc and the CLAUDE.md "261 = K20 HK1" fact) — not a server contract. |
| `hocvien/thongkectdt` (`getThongKeCTDT`) | **[2026-09-25] `GET /api/student/me/graduation-summary`** | grades_screen (overview tab) | Originally implemented as client-side arithmetic over `/me/grades` + `/me/remaining-subjects`; corrected 2026-09-25 to use `/me/graduation-summary` directly (`routes/portals/student-portal.js:91`, `lib/portals-student-portal-service.js#getGraduationSummary`), which returns `{student, academic, attendance, tuition, eligibility, remaining_subjects}`. Only `academic` and `remaining_subjects` are parsed (`lib/models/crm_student_graduation_summary.dart`) — `tuition`/the finance half of `eligibility` are real fields in the response but are OUT OF SCOPE for this slice (owned by tuition_screen.dart/lephi_screen.dart) and are deliberately left unparsed, not missing. `academic` is SUBJECT-COUNT based (`total`/`scored`/`passed`/`failed`, `required_subjects`/`required_passed` — the server's `summarizeGrades()` counts grade rows, it never sums `credits`); the overview now shows "X/Y **môn**", not tín chỉ, and no longer does any client-side credit or average arithmetic. `average_score` is one number (10-point scale), shown for both "tích lũy" and "tổng kết" since the CRM does not distinguish them. |
| `hocvien/bangdiemtongket` (`getBangDiem`) | `GET /api/student/me/grades` | grades_screen | **[2026-09-25]** Letter grade uses the SCHOOL'S REAL 8-band ladder, ported byte-for-byte from crm-clean's `lib/grades/diem4.js` (`letterGradeForScore` in `lib/models/crm_student_grades.dart`: A ≥8.5, B+ 8.0–8.4, B 7.0–7.9, C+ 6.5–6.9, C 5.5–6.4, D+ 5.0–5.4, D 4.0–4.9, F <4.0) — not a generic A/B/C/D/F guess. A null score or one outside [0,10] (IMS carries out-of-range garbage, e.g. `final_score` 54.2) maps to **no letter** ("—" in the UI), never 'F' — banding it would launder dirty data into a fake grade. `/me/grades` rows carry no `diem4` field today; if one ever appears, `letterGradeForDiem4` is preferred over re-deriving from `final_score`. A row with `final_score: null` (any `status`, including `pending_review`) is "chưa có điểm" (`isUngraded`), never counted as failed. `solan` (lần học lại) is recomputed client-side from the raw `/me/grades` list (grouped by `subject_code`, ordered by `semester_code`/`recorded_at`) since the server doesn't number retakes itself. |
| `hocvien/bangdiemhocky` (`getBangDiemHocKy`) | not called by any screen in this slice | — | Dead code in the old `api_service.dart`; no screen in this slice used it, so nothing to migrate. |
| `hocvien/monhocchuadat` (`getMonHocChuaDat`) | `GET /api/student/me/remaining-subjects` | grades_screen ("Chưa học" tab) | Server's `completion_status` (`passed`/`not_taken`/`pending`/`failed`) maps to the old `trangthai` (0/1/2) as: `pending`→1 (Đang học), `failed`→2 (Không đạt), else→0 (Chưa học). `passed` rows are already excluded server-side. |
| `hocvien/lichthi?ngayBD=` (`getExams`) | `GET /api/student/me/exams?semester=` | exam_screen | **Contract changed under us mid-build (2026-09-25):** no `semester` (or `semester=all`) now returns the FULL history, newest first; `?semester=<code>` filters to one semester. The screen fetches full history on load (default view = "Tất cả các học kỳ"), derives the semester dropdown from that result, and calls `exams(semester: code)` fresh — not a client-side filter — whenever the user picks a specific semester, so what's shown always matches what the server considers that semester's exams. `room` is frequently `null` (IMS data-quality gap per the server doc, not a join bug) — shown as "—". |
| `hocvien/dotdangky`, `hocvien/monhocdukien`, `hocvien/ketquadk` | out of scope | — | Belong to registration_screen.dart / tuition/lephi, owned by other bots per the brief. Not touched. |

## Other notes

- **Home header** (`hv_home_screen.dart`): name and MSSV now come from
  `AppSession.instance.fullName`/`mssv` (the CRM login identity), never from
  `hocVien` (confirmed permanently unpopulated since 6.1.0's login-core
  rewrite, per `app_session.dart`'s own doc comment). Class code (`_malop`)
  has no AppSession field, so it is fetched once from `GET /api/student/me`
  on screen load and cached in state.
- **Unrelated pre-existing gap noticed, not fixed (out of this slice's
  scope):** `hv_home_screen.dart`'s notifications-bell unread count
  (`_loadUnreadCount`) calls a separate third-party Vercel backend keyed by
  `AppSession.instance.hocVien?.id`. Since `hocVien` is never populated any
  more, this silently no-ops (early return) on every login. Not an IMS/CRM
  endpoint and not in this bot's file list to fix; flagged for whoever owns
  that Vercel integration.
- **Home "today's schedule"** now derives from the full `/me/schedule` feed
  filtered by `CrmScheduleItem.occursOn(today)` (see the schedule row above)
  rather than a per-day IMS call.
- `hv_profile_info_screen.dart` stays READ-ONLY per the brief: the edit
  action still calls nothing new (`TODO(A4)` left in place for whoever owns
  profile-edit/change-password-from-profile).
