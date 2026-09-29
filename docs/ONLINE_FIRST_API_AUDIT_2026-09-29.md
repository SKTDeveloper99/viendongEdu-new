# Mobile CRM calculation and morning-load audit

Reviewed 2026-09-29. This is a source audit; it does not replace a production load test.

| Domain | Current authority / phone work | Result |
|---|---|---|
| Login, permissions, questions routing, attendance writes | CRM endpoints; the phone sends chosen values and reads the saved roster back | CRM authoritative. No IMS request in the live route graph. |
| Tuition, fees, registration, graduation summary | CRM service responses; the phone parses and displays them | CRM authoritative for shown totals. Downstream IMS sync policy still needs school approval. |
| Teacher overview | CRM `/teacher/me/overview` builds today sessions and summary; phone renders them | CRM authoritative, but the initial request runs several DB queries per teacher. Server peak capacity remains unmeasured. |
| Grade letters and pass badges | Phone still maps `final_score`/`diem4` to letter and pass result | **Gap:** publish `grade_letter` and `is_passed` from CRM, then remove the phone rule after backend deployment. Current app mirrors the CRM ladder but is a second source of logic. |
| Student today's schedule | Phone filters the CRM schedule with `occursOn` and local device date | **Gap:** a server-provided `today` endpoint in Vietnam time would remove phone date/week interpretation. |
| Attendance counts, list sorting, display labels | Phone counts/rendering only; individual statuses come from CRM | Display-only calculations; do not write them as academic truth. |

## Online-first behavior

Home, attendance, teacher My Day, and question lists/details show a connection error rather than automatically opening saved server data. The student attendance screen no longer polls every 30 seconds. Teacher selections remain locally saved if a write fails, clearly labeled **CHƯA GỬI**, and require a manual retry after connection returns. No background submission is implied.

## Morning burst changes and remaining server work

Teacher sign-in is paced within 0–700 ms by account. The first teacher overview is paced within 0–900 ms, and the secondary unread-count call starts 1.2–2.6 seconds later. Student secondary home calls start after the schedule. FCM token retrieval no longer blocks teacher login and the duplicate student token registration was removed. Reads time out after 7 seconds; writes retain 15 seconds.

Phone pacing reduces synchronized bursts but cannot establish server throughput. The CRM overview uses an in-memory cache keyed per teacher and semester; first requests from many distinct teachers still reach SQL. Before mass release, load-test the 7 a.m. teacher login + overview + attendance mix on a production-like copy, measure p95/p99 and pool wait, then reduce query work or add capacity based on the result. The questions API still needs an idempotency key for safe retries.
