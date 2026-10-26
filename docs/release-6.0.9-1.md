# 6.0.9 (1) iOS, 6.0.9 (103) Android

Branch `park/infinite`, from `release/6.0.8-2` + the Infinite park.

## Why this release

2026-10-26: Android students who had the new app showed "Chưa điểm danh"
after the teacher marked them on EMS. Play was serving 101 (tdat535's
6.0.8, published 2026-10-20, no update gate); our 102 was also named 6.0.8
and was never published (still in "Changes ready to publish"). iPhones were
on our 6.0.8 (2) and were fine.

## What's new (store text)

- Viễn Đông Infinite tạm dừng, không còn trên màn hình chính.
- Ứng dụng nhắc cập nhật chính xác hơn khi có bản mới.

## Changes

1. Infinite: no home tile, no `/infinite` route (game code and tests stay).
2. Update gate: server may send `android_min_build` / `ios_min_build`;
   a lower build number is blocked even when the name matches `min_version`.
3. `android/play_releases.json` records every Play upload from any branch;
   `test/play_release_ledger_test.dart` fails on a repeated versionCode or a
   versionName another line shipped.

## After it is live

- Server `/app/min-version`: `min_version` 6.0.9, `android_min_build` 103,
  `ios_min_build` 1. Fix `ios_url` (currently `.../app/id0`).
- 101 has no gate. Only a Play **production** update replaces it; open
  testing reaches only people who join the test.
