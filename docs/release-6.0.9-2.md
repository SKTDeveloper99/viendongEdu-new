# 6.0.9 (2) iOS, 6.0.9 (104) Android

Branch `park/infinite`, 6.0.9 (1) + the roster save status. Owner GO
2026-11-03 ("update the phone app version if needed").

## Why this release

2026-11-03: Linh (20MNC_N3 Mỹ thuật) pressed Lưu 2–3 times every class
because the screen looked the same before and after a save, and her 29/10
roster never left the phone (no request reached the server; the draft was
found on her phone five days later and saved at 18:15). Nothing on the
roster said whether the server had the marks.

## What's new (store text)

- Màn hình điểm danh luôn báo "ĐÃ LƯU ✓ lúc …" hoặc "CHƯA LƯU".

## Changes

1. Roster bottom bar: green `ĐÃ LƯU ✓ lúc HH:MM dd/MM` when the marks on
   screen equal the server's (`marked_at` from the roster API), red
   `CHƯA LƯU • bấm Lưu điểm danh để gửi` when they differ; an offline roster
   is never shown as saved.
2. Cancelling the "chưa điểm danh" or Khác/Vắng prompt shows "CHƯA LƯU —
   chưa gửi gì lên máy chủ." instead of nothing.
3. A newer toast replaces the one on screen instead of queuing behind it.

Server side (already live, CRM `4aa8c78`): a past class with no attendance
is listed as "chưa điểm danh" in the class's Buổi học tab instead of
disappearing.

## After it is live

- Server `/app/min-version` unchanged; raise `android_min_build` 104 /
  `ios_min_build` 2 only if the owner wants to force it.
