# 6.0.8 (2) iOS, 6.0.8 (102) Android

Branch `release/6.0.9-102`, from `release/6.0.8-1` (6.0.8 (1), versionCode 100).
101 is taken by tdat535's 6.0.8.

## What's new (store text)

- Sinh viên mọi khóa xem được lịch học, lịch thi, điểm, học phí và điểm danh.
- Lớp học hiện ngày bắt đầu và ngày kết thúc môn.
- Lịch học báo khi lớp có tuần nghỉ.
- Thông tin chưa có hiện "N/A" thay vì số 0.
- Giảng viên: bảng Tổng hợp điểm danh đếm đúng buổi đã điểm danh trên EMS.

## Changes

1. Student data gate follows the server's `data_open`; otherwise open by default
   (`lantern_min_prefix` 0 on 6.0.9+). Remote Config can still close it.
2. Teacher "Tổng hợp": attended / due sessions with a mark, EMS marks first,
   present + late + excused count as attended (same rule as "Buổi học").
   No mark at all shows N/A, never 0/n.
3. Grades overview: no summary / no average shows N/A, not 0.00. Registration
   "Sĩ số" shows N/A when unknown.
4. Student class card and detail show Bắt đầu / Kết thúc (N/A when unknown).
5. Timetable flags a class whose weeks pattern has a break ("có thể không học
   tuần này"); the phone has no term start, so it does not guess which week.

## Live switch (no release needed)

Firebase Remote Config `lantern_min_prefix` = **1**. 6.0.8 phones read 0 as 25,
so 1 is what opens both old and new builds.

## Checks

- `flutter test`: 554 pass, 1 known failure from 2026-10-19
  (`announcement_body.dart` colour literals, architecture guard). Not tonight's.
- `flutter analyze`: no issues.

## Not in this build

The 304-site N/A sweep, Codex night branches (a11y, perf, offline errors,
screen tests, Vietnamese text), decoding skipped weeks exactly (needs the term
start from the server).
