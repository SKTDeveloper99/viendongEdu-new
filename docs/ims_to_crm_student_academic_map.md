# IMS → CRM map — student academic screens (bot A3)

Scope: `lib/screens/hv_home_screen.dart`, `schedule_screen.dart`,
`classes_screen.dart`, `grades_screen.dart`, `exam_screen.dart`,
`hv_profile_info_screen.dart`, `student_board_screen.dart` (already CRM-only),
`ems_attendance_student_screen.dart` (already CRM-only). New files:
`lib/services/crm_student_api.dart`, `lib/models/crm_student_profile.dart`,
`lib/models/crm_student_grades.dart`, `lib/models/crm_student_schedule.dart`,
`lib/models/crm_student_exams.dart`, `lib/services/crm_session_guard.dart`.

Server contracts were read from `/Users/khoatran/Desktop/crm-clean` (routes,
lib, repositories) and from the exam-endpoint doc in that repo's worktree
`.claude/worktrees/agent-a86dcd5eb8ad283d1/docs/api/mobile-ims-replacement-S3.md`.
Nothing below is guessed from naming conventions alone.

## Call map

| Old IMS call (`api_service.dart`) | CRM endpoint | Screen(s) | Gap / behaviour change |
|---|---|---|---|
| `hocvien/user/info` (`getUserInfo`) | `GET /api/student/me` | hv_profile_info_screen, hv_home_screen (header) | `students.cccd` exists in the DB but the portal's `getStudent()` SELECT does not return it — CCCD shown as "—". CRM has one ngành level only; "chuyên ngành" shown as "—". |
| `hocvien/tkbtheongay?ngay=` (`getScheduleByDate`, `getTodaySchedule`) | `GET /api/student/me/schedule?semester=` | schedule_screen, hv_home_screen (today card) | IMS was per-DAY; CRM is per-SEMESTER, weekly-recurring (day_code + start/end time + `weeks_pattern`/`tuanhocstr`, undocumented encoding). A date is matched client-side by weekday + `[start_date, end_date]` (`CrmScheduleItem.occursOn`) — a class that meets on alternating weeks may over-show on some dates, since `weeks_pattern` is not decoded. `buoi` (sáng/chiều/tối) no longer exists server-side; derived client-side from the start hour. `loaitkb == 'lichthi'` (exam rows mixed into the day feed) has no equivalent — exams are a separate endpoint/screen now. `baonghiyn` (báo nghỉ flag on the schedule row) has no CRM equivalent; the EMS-attendance-mark lookup is the only source of "excused" now. |
| `hocvien/lopmonhoc?hockyid=` (`getLopMonHoc`) | `GET /api/student/me/sections?semester=` | classes_screen | No per-class evaluation weights (`tylecc`/`tylegk`/`tyleck`) or syllabus text (`decuong`) on the CRM side — these were already dead/unused in the old screen's widget tree, so nothing user-visible regresses. No `diemcc` (chuyên cần) score exists; only midterm (`diemgk`) and final-exam (`diemck`) come from `/me/grades`, matched by `section_code` (falling back to subject_code+semester for hand-entered grade rows with no LMH). No `lmhid` (IMS surrogate key) any more — EMS attendance for a class is now matched by `section_code`, not an id prefix. |
| `hocky` (`getHocKy`) | **no student endpoint** | classes_screen, exam_screen | CRM has `GET /api/teacher/me/semesters` (teacher-only — verified by reading `routes/portals/teacher-portal.js`); there is no student equivalent. The semester list is DERIVED from distinct `semester_code` values in `/me/sections`, labelled by `semesterCodeLabel()` (a client-side formula: 2-digit year + 1-digit semester, matching the one confirmed real sample in the exams doc and the CLAUDE.md "261 = K20 HK1" fact) — not a server contract. |
| `hocvien/thongkectdt` (`getThongKeCTDT`) | **no equivalent** | grades_screen (overview tab) | No single "tổng kết chương trình" endpoint. The overview stats (tín chỉ đạt/tổng, ĐTB) are computed client-side from `/me/grades` + `/me/remaining-subjects`: credits-passed and credits-failed/no-score come from actual grade rows; the "Y" denominator in "X/Y tín chỉ" only reflects the real program size when `has_curriculum == true` (otherwise it falls back to credits actually graded, rather than inventing a program total). Server reports one `average_score` (10-point scale); shown for BOTH "tích lũy" and "tổng kết" since the CRM does not distinguish them. |
| `hocvien/bangdiemtongket` (`getBangDiem`) | `GET /api/student/me/grades` | grades_screen | No letter grade (A/B/C/D/F) anywhere in the CRM — `CrmStudentGrade.gradeLetter` is a CLIENT-SIDE display convention (standard 10-point Vietnamese scale), not sourced data; documented in the model file. No 4.0-scale GPA (`diem4`) — was already dead/commented-out in the old screen, not reintroduced. `solan` (lần học lại) is recomputed client-side from the raw `/me/grades` list (grouped by `subject_code`, ordered by `semester_code`/`recorded_at`) since the server doesn't number retakes itself. |
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
