# Viễn Đông Infinite — UI and Art Direction Proposal

**Status:** proposal only · **Audience:** product owner, design, Flutter team · **Target:** Vietnamese students, roughly 16–22

## Product guardrails

- Every reward is cosmetic. No purchases, paid currency, grades, tuition, money, or attendance benefits; quest participation is voluntary and never changes academic records.
- Keep the game loop small and campus-safe: choose a quest → do a lightweight activity → claim a cosmetic/XP/Sao → customize or share. GPS/QR are optional activity proofs, not an attendance system.
- All widget colors resolve through `context.vd.*`. Existing semantic tokens in `lib/theme/vd_tokens.dart` remain the base; any direction-specific colors below are proposed additions to `VdTokens`, including light and dark values. Never put raw `Color(...)` values in widgets.
- Product-facing text is Vietnamese. Examples below are UI-ready Vietnamese strings; this proposal is written in English.
- Original characters and original asset shapes only. References describe interaction and pacing, never permission to reproduce characters, logos, signature costume silhouettes, or trademarked motifs.
- Target low-end Android (2–3 GB RAM): mostly static vector art, one active animation at a time, avoid full-screen particle fields/blur, cap particles, pause off-screen animation, and honor `MediaQuery.disableAnimationsOf(context)`.

## 1. Reference board

These are interaction references, not art templates. “Popular” is used broadly: major mobile titles plus distinctive cozy/habit-led games with patterns relevant to this audience. Popularity varies by market and date.

| Game | Borrow specifically | Why it fits a school app |
|---|---|---|
| **Pokémon Sleep** ([official](https://www.pokemonsleep.net/en/)) | Calm daily return ritual, friendly creature reactions, collection discovered through repeated ordinary actions. | Makes a small recurring habit feel cared for; use the gentle cadence, not sleep tracking or Pokémon-like creatures. |
| **Sky: Children of the Light** ([App Store](https://apps.apple.com/us/app/sky-children-of-the-light/id1462117269)) | Seasonal quest giver, aspirational shared world, warm reward reveal with restrained light. | “Sổ Hành Trình” can feel like a semester journey with a welcoming guide; keep effects short and 2D. |
| **Genshin Impact** ([official](https://genshin.hoyoverse.com/en/)) | Clear rarity hierarchy, collection catalog, strong item naming and reveal pacing. | Makes cosmetic collections legible and exciting. Avoid copying its fantasy UI, symbols, or gacha presentation. |
| **Honkai: Star Rail** ([official](https://hsr.hoyoverse.com/en-us/)) | Premium-feeling reward card, readable tiered progression, concise quest panel hierarchy. | Gives the pass and level-up moments structure; translate to friendly campus language, not sci-fi styling. |
| **Subway Surfers** ([official](https://sybogames.com/games/subway-surfers/)) | Immediate daily/weekly missions, bold progress meter, quick claim feedback. | Students can understand what to do in a glance and return between classes. |
| **Stumble Guys** ([official](https://www.stumbleguys.com/)) | Chunky silhouettes, playful emotes, readable rewards on small screens. | A light, social tone suits 16–22 without making the app look like a children’s learning tool. |
| **Animal Crossing: Pocket Camp Complete** ([official](https://ac-pocketcamp.com/en-US/)) | Cozy collection book, themed event sets, “one more item” completion rhythm. | Campus keepsakes and event cosmetics can be collected without competitive pressure. |
| **Sky: CotL seasonal quest pages** ([help center](https://thatgamecompany.helpshift.com/hc/en/17-sky-children-of-the-light/faq/773-how-do-daily-quests-work-between-seasons/)) | A visible daily quest-giver anchor and seasonal context around short tasks. | The side-cast can contextualize quests and events without adding complex navigation. |
| **Finch** ([official approach](https://help.finchcare.com/hc/en-us/articles/37935669335309-Our-Approach-to-Self-Care)) | Gentle streak framing, supportive buddy language, no shame when a day is missed. | A school-day streak should encourage, never punish; streak freeze should be explained clearly and used compassionately. |
| **Monument Valley** ([official](https://www.monumentvalleygame.com/)) | Quiet negative space, geometric framing, restrained transitions and visual confidence. | Balances arcade systems with a polished college identity and keeps screens uncluttered. |

## 2. Three art directions

### A. Saigon Pocket Journal — recommended

**Mood:** warm, sociable, breezy, locally rooted; a student’s illustrated pocket notebook collecting campus memories. Use abstract campus architecture, afternoon shade, rain-cloud pauses, and subtle paper grain. Avoid tourist-poster clichés.

**Proposed token additions** (hex is the light/dark value pair):

| Token | Light | Dark | Use |
|---|---:|---:|---|
| `infiniteJade` | `#247C70` | `#70C6B4` | discovery, school-day progress |
| `infiniteJadeSoft` | `#DDF1EA` | `#203D38` | jade surfaces |
| `infiniteSaffron` | `#D99435` | `#F2BC67` | Sao, rare accents |
| `infiniteSaffronSoft` | `#FFF0D5` | `#44351F` | Sao backgrounds |
| `infiniteCoral` | `#D86F58` | `#F19A83` | warm character accent |
| `infiniteCoralSoft` | `#F9E4DC` | `#482B28` | event callouts |
| `infiniteSky` | `#78BBD0` | `#4D899A` | QR hunt / breezy backdrop |
| `infinitePaper` | `#F5EEDC` | `#2C2923` | journal panel; dark is a deep paper-ink surface |

Keep body text on existing `ink`/`inkMuted`; pair accent fills with validated contrast. Rarity can use existing semantic tokens plus proposed `infiniteJade`, `infiniteSaffron`, and `infiniteCoral`; Huyền thoại gets a warm foil pattern, not a new glowing rainbow color.

**Shapes:** rounded notebook cards (18–24 dp), ticket tabs, stitched/dotted progress tracks, layered paper corners, simple hand-cut silhouettes. Rarity frame borders use patterns/icons as well as color.

**Typography:** existing Vietnamese-capable app sans for all functional text. Use a restrained display face only for large event/season titles after confirming full Vietnamese diacritics and licensing. Keep numerals tabular for XP/Sao; avoid handwriting for instructions.

**Lobby sketch:**

```text
┌ Viễn Đông Infinite ───────── Sao  ✦ 120 ┐
│ Chào buổi chiều, Minh!                   │
│  [MÈO MƯỚP mascot + avatar/frame]        │  “Cùng mở trang mới nhé!”
│  Cấp 08  ━━━━━━━●────  340 / 500 XP     │
│  SỔ HÀNH TRÌNH · 12/30   [Xem hành trình]│
├ Hôm nay tại Viễn Đông ───────  2/3 ──────┤
│ [quest card: Ghé thư viện…  +20 XP]      │
│ [quest card: Tìm QR …          +1 Sao]   │
├ Bộ sưu tập mới                    [Mở sổ]│
│ [frame] [title] [silhouette ???]         │
└ Nhiệm vụ     Hành trình     Bộ sưu tập   ┘
```

### B. Neon Campus Arcade

**Mood:** energetic, youthful, high-contrast; student club night meets arcade ticket booth. Strong for short claims and event bursts, but less calm for daily use.

| Token | Light | Dark | Use |
|---|---:|---:|---|
| `infiniteArcadeBlue` | `#2557B7` | `#82A8FF` | primary game progress |
| `infiniteArcadeBlueSoft` | `#E2EAFF` | `#202D4B` | progress surface |
| `infiniteArcadeLime` | `#6E9F2E` | `#B7E86F` | completed/quest accents |
| `infiniteArcadeLimeSoft` | `#ECF5D8` | `#303E22` | lime surfaces |
| `infiniteArcadePink` | `#C44788` | `#F184BD` | event accent |
| `infiniteArcadePinkSoft` | `#F8E2EF` | `#45283A` | event panel |
| `infiniteArcadeAmber` | `#C27A14` | `#FFC46E` | Sao/claim |
| `infiniteArcadeAmberSoft` | `#FFF0D9` | `#45331F` | reward panel |

**Shapes:** thick 2–3 dp outlines, ticket notches, pixel-inspired dashes (not pixel art), large counters, sharp-to-round mixed geometry. **Typography:** robust app sans with condensed display numerals; never use stylized type in long Vietnamese copy.

**Lobby sketch:**

```text
┌ VIỄN ĐÔNG INFINITE ─────── LV.08 / ✦120 ┐
│   (mascot jumps through a ticket ring)   │
│ MINH · CẤP 08     XP ███████░░ 340/500  │
│ [DAILY RUN 2/3] [WEEKLY 4/8]             │
│ [CLAIM +20 XP]     [SỔ HÀNH TRÌNH 12/30]│
│ NHIỆM VỤ  |  THÀNH TÍCH  |  KHO ĐỒ       │
└ neon gradients restricted to one small hero zone ┘
```

### C. Họa Tiết Sân Trường — Vietnamese folk / paper-craft

**Mood:** contemporary Vietnamese craft book: cut paper, school notebook margins, Đông Hồ-inspired flatness in broad compositional terms only. Commission original motifs; do not trace folk paintings or use sacred/historic motifs as generic decoration.

| Token | Light | Dark | Use |
|---|---:|---:|---|
| `infiniteLacquer` | `#8F342C` | `#E88979` | hero/event accent |
| `infiniteLacquerSoft` | `#F4E3DC` | `#422725` | accent surface |
| `infiniteIndigo` | `#344E73` | `#90A9D0` | quest/action |
| `infiniteIndigoSoft` | `#E5EAF1` | `#28313D` | indigo surface |
| `infiniteRice` | `#F3E9D0` | `#302B22` | paper ground |
| `infiniteBamboo` | `#66805A` | `#A9C39A` | streak/growth |
| `infiniteBambooSoft` | `#E7EEDD` | `#2B3629` | bamboo surface |
| `infiniteBrass` | `#B1843A` | `#E3BD72` | reward ornament |

**Shapes:** folded-paper tabs, layered cutouts, border blocks, leaf/lantern abstractions; no fine ornamental lines that collapse on phone. **Typography:** app sans for reading; optional Vietnamese display serif for headers, proofed at small sizes and with diacritics.

**Lobby sketch:**

```text
┌ SỔ HÀNH TRÌNH ─────────────── ✦ 120 ┐
│ ╭ paper-cut campus gate / mascot ╮   │
│ │ MINH · Cấp 08 · 340/500 XP    │   │
│ ╰───────────────────────────────╯   │
│ Một ngày mới, một dấu mộc mới         │
│ [Nhiệm vụ trong ngày] [Quét QR]       │
│ DẤU MỘC ĐÃ SƯU TẦM   [album preview]  │
└ giấy xếp lớp, limited shadow, no texture noise ┘
```

### Recommendation

Choose **Saigon Pocket Journal**. It connects the college identity to daily student life without making the experience feel like a children’s reward chart. Its paper, jade, and warm coral palette is comfortable for repeated use and supports both the celebratory 20/11 event and calm daily tasks. It also converts cleanly to lightweight vectors and share cards. Borrow the folk/paper craft direction as occasional event art, and reserve arcade punch for claim feedback and level-up moments.

## 3. Original mascot cast

All designs below are new briefs. Use distinct proportions and silhouettes; no Pokémon-like creature language, game mascots, borrowed costume shapes, or school-logo impersonation.

| Character | Look / personality | Role | 3 expression or pose states | Sample Vietnamese lines |
|---|---|---|---|---|
| **Mướp** (hero) | Small Saigon alley cat with cream-and-ginger coat, teal notebook sling, one asymmetrical ear, tiny school lanyard with a blank geometric tag. Curious, quick, never scolding. | Lobby guide, quest companion, reaction anchor. | `Chào` upright wave; `Tò mò` leaning with notebook; `Ăn mừng` tiny hop/paws up. | “Chào bạn, mình cùng khám phá nhé!” · “Thêm một dấu mốc mới rồi!” |
| **Bắp** | Pigeon with a cobalt messenger pouch and a single folded paper map; city-wise and helpful, not a generic tourist pigeon. | Campus QR hunt guide; points out clue context. | `Chỉ đường` wing point; `Đã tìm thấy` wing spread; `Nghỉ` tucked-in perch. | “Mã QR tiếp theo ở khu vực sinh hoạt chung đó!” · “Mình tìm thấy dấu mốc rồi!” |
| **Ly** | Original reusable campus tumbler with small sticker collage and a leaf-shaped straw cap; practical, upbeat. | Streak buddy and streak-freeze explainer; supports gentle comeback. | `Cổ vũ` tilted cheer; `Nhắc nhẹ` calm notice; `Nghỉ ngơi` lid closed. | “Hôm nay còn một nhiệm vụ ngắn nè.” · “Bạn có thể dùng Khiên Chuỗi ngày để giữ nhịp.” |
| **Bánh Mì** | Compact baguette-shaped library cart spirit with sesame freckles and a tiny book stack; warm, quick-witted. | Chest keeper; introduces chest rarity and pity transparency. | `Mời mở` hatch open; `Bất ngờ` crumb sparkle; `Chúc mừng` book salute. | “Mở hộp quà nhé—mọi phần thưởng đều là vật phẩm trang trí!” · “Lần này là một món Hiếm!” |
| **Sen** | Lotus-bud lantern made from layered paper, with a simple face and a school scarf; thoughtful and kind. | Event host for “Tri ân Thầy Cô”; presents story-chain pages. | `Lắng nghe` soft eyes; `Trao thiệp` holding card; `Tỏa sáng` lantern glow. | “Viết một lời cảm ơn theo cách của bạn nhé.” · “Mỗi lời nhắn là một trang ký ức.” |

### Reaction map

| Moment | Reaction |
|---|---|
| Quest complete | Mướp’s `Ăn mừng`, one quick paw-hop, says “Nhiệm vụ hoàn thành! +20 XP” then settles. |
| Level up | Mướp holds the new level badge; Bắp briefly flutters in from edge. “Lên cấp rồi! Cấp 09 nhé!” |
| Streak at risk | Ly shows `Nhắc nhẹ`, calm neutral colors and a clear option; no alarm, red warning, or guilt language. “Bạn muốn dùng Khiên Chuỗi ngày không?” |
| Chest open | Bánh Mì lifts lid; reveal follows rarity intensity and then displays exact item name and rarity. |
| Rare drop | Bánh Mì’s `Bất ngờ`, Mướp leans in; “Hiếm quá! Bạn nhận được [tên vật phẩm].” Huyền thoại may add Sen’s short lantern glow. |

## 4. Effects and “juice” catalogue

Haptics are optional system feedback: use Flutter `HapticFeedback` sparingly; no continuous vibration. Sound should be authored original, short, normalized, and switchable in settings. Durations include reveal/transition time. For reduced motion, replace movement and particles with instant state change, static rarity badge, and a brief accessible text announcement; never hide information in animation.

| Moment | Animation / duration | Haptic / sound | Flutter technique | Reduce-motion fallback |
|---|---|---|---|---|
| Quest claim | Card compresses 0.98→1, checkmark draws, reward chip appears; 350–500 ms. | Light selection; soft original “tick” (≤200 ms). | `AnimatedScale`, `AnimatedSwitcher`, `TweenAnimationBuilder`; no engine. | Immediate check state and `+XP` text. |
| XP bar fill | Bar interpolates to target, numeric count rolls once; 500–800 ms. | None; quiet rising two-note cue only on level threshold. | `TweenAnimationBuilder<double>` or `AnimationController`, `ClipRRect`; clamp offscreen. | Set final value immediately; announce “Cấp 08, 340 trên 500 XP”. |
| Level up | Badge scales once, small 6–10 dot burst; 700–950 ms. | One light impact; original 3-note chime (≤700 ms). | Implicit scale + small `CustomPainter` particle overlay, seeded deterministic. | Static new-level badge and concise dialog. |
| Chest: Thường | Lid/card lifts and item slides in; 650 ms. | Soft tap + paper pop (≤180 ms). | `AnimatedContainer`/`AnimatedSlide`; asset-free vector. | Reveal item immediately, label “Thường”. |
| Chest: Hiếm | Two-step open, jade edge sweep, 10 particles max; 900 ms. | Medium impact, short original chime (≤450 ms). | `CustomPainter` bounded particles or pre-rendered Lottie. | Static jade rarity frame, item name, no sweep. |
| Chest: Sử thi | Brief pause then coral foil card reveal, 16 particles max; 1,100 ms. | Medium impact + short original chord. | Rive state machine for Bánh Mì or Lottie; one instance only. | Show static foil-pattern card with “Sử thi”. |
| Chest: Huyền thoại | 1.3–1.6 s staged reveal, silhouette then warm lantern line, max 20 particles. | Single stronger impact + original 700 ms motif; honor haptics off. | Reusable Rive mascot state plus `CustomPainter` particles; cap draw area. | Skip staged suspense; static legendary border + explicit item details. |
| Streak milestone | Day markers fill left-to-right, Ly bobs once; 500–700 ms. | Light tap at milestone only; no daily nag sound. | `AnimatedContainer` per visible marker, small Rive/Lottie only if already loaded. | Set markers at once; show text “Chuỗi 5 ngày học”. |
| Equip cosmetic | Avatar frame crossfades, title chip settles; 250–400 ms. | Selection click; no reward sound. | `AnimatedSwitcher`, `AnimatedContainer`; preserve existing `CosmeticAvatar` frame behavior but pause when offscreen. | Swap instantly. |
| Season tier unlock | Tier tile flips/fades to owned, progress track advances; 500–700 ms. | Soft tick; milestone chord only at key tier. | `AnimatedSwitcher` + `TweenAnimationBuilder`; no 30 simultaneous animations. | Show owned marker and updated tier count. |
| Share card | Preview fades in; export itself has no animation dependency; 250 ms preview. | None. | Compose a fixed-ratio Flutter widget; export raster with `RepaintBoundary`/`toImage`, then platform share sheet. | Static preview; share action remains usable. |

**Motion defaults:** durations under 1.6 s, no loops outside the visible hero, no camera shake, flashing, or parallax. Check `MediaQuery.disableAnimationsOf(context)` before starting any controller and stop controllers when a route is not visible. Keep all colors token-backed; rarity can use patterns and icon shapes to remain distinguishable in monochrome.

**Runtime/license position:** Flutter implicit animations and `CustomPainter` need no added package. If custom-authored files are useful, Rive’s official runtimes are MIT licensed ([runtime overview](https://github.com/rive-app/help-center/blob/master/runtimes/overview.md)); Flutter Lottie package is MIT ([package license](https://pub.dev/packages/lottie/license)); Flame is an open-source Flutter game engine, but is unnecessary for this 2D UI proposal and its exact package license/version should be checked before adoption. Runtime licensing does not grant rights to art files: require written rights for commissioned assets and retain source files. No paid SaaS or paid asset-store dependency is proposed.

## 5. Screen map

Current implementation has `InfiniteScreen`, `LobbyHero`, `QuestCard`, `CosmeticAvatar`, and `CosmeticTile`; `InfiniteViewModel` loads quests/claims/unlocks/equipment. Keep those as the visual foundation. Existing data model currently covers quests and 7 cosmetics; XP/season/events are planned UI concepts and would need existing product APIs/state before implementation. This proposal does not assume new persistence.

| Screen / sheet | Key components and behavior | Reuse |
|---|---|---|
| **Lobby** | Compact level + XP + Sao header; Mướp hero; season pass teaser; today’s quest preview; streak card; 3-item recent collection strip. | `InfiniteScreen`, `LobbyHero`, `CosmeticAvatar`; adapt `QuestCard` to compact preview. |
| **Quest board** | Tabs `Hôm nay` / `Tuần này`; daily/weekly cards; QR hunt entry; optional code entry; claim state; explanation that rewards are cosmetic. | `QuestCard` for URL/code/GPS flow, with optional new card variant. |
| **Sổ Hành Trình** | 30-tier vertical/horizontal track; free reward at every planned tier; current tier pinned; locked/claimed markers; season dates and cosmetics preview. | `CosmeticTile` preview style and token-backed progress patterns. |
| **Bộ sưu tập** | Filters by `Khung`, `Danh hiệu`, `Bạn đồng hành`; rarity label; `???` silhouettes; earned/equipped distinction; item detail sheet. | `CosmeticTile`, `CosmeticAvatar`; expand from owned-only grid to catalog presentation. |
| **Chest opening sheet** | Chest odds/pity explanation before open; reveal stage; exact reward, rarity, “Trang bị” and “Xem trong bộ sưu tập”. No purchase CTA. | Reuse rarity badges and item cards from collection. |
| **Profile / share card** | Name, level, equipped frame/title, selected mascot pose, favorite cosmetics, optional school/event theme; preview and share. Do not expose student ID, grades, schedule, exact location, or private data. | `CosmeticAvatar` and equipped `CosmeticTile` presentation. |
| **Event page: Tri ân Thầy Cô** | Event hero, optional story chain, daily prompts/creative participation, cosmetic reward preview, 20/11 event collection set. Teacher appreciation wording; no teacher ranking or attendance requirement. | `LobbyHero` banner treatment, `QuestCard`, `CosmeticTile`. |
| **Streak-freeze confirm sheet** | Current streak, what freeze does, available freeze count, explicit `Dùng khiên` / `Để sau`; no shame copy. | Shared bottom-sheet pattern; Ly portrait. |

Use one primary scroll axis per screen, accessible hit targets, clear empty/loading/error states, and Vietnamese diacritics. QR hunt should have a manual fallback/support message for camera permission or poor connectivity; QR tasks must remain optional.

## 6. Asset production plan (no art budget)

1. **Art bible first (S, 2–3 days):** lock silhouettes, line weight, palette tokens, expression set, rarity border grammar, export sizes, and prohibited lookalikes. Owner/design review before making the full cast.
2. **Vector kit (S, 3–5 days):** draw Mướp and 3 poses in Figma or Inkscape as simple closed paths. Keep character assets independent of app colors where possible; apply palette through documented token mapping. Export SVG for static Flutter rendering where current stack supports it, or PNG/WebP at 1x/2x for raster-safe fallback. Store editable source (SVG/Figma export) with attribution and usage rights.
3. **Animation (S/M, 3–5 days):** make only Mướp idle/cheer and chest reveal for Slice A. Rive runtime MIT or Lottie Flutter package MIT can play authored assets; authoring/export terms differ by tool and must be reviewed. Keep Rive state inputs to a few booleans/triggers, or use Lottie for fixed sequences. For hand-built effects use Flutter implicit animations and `CustomPainter`.
4. **Student art club (M, 1–2 weeks part-time):** invite illustration/design students for optional concept jam; provide a one-page brief and consent/credit form. Agree in writing that the college can use/edit/ship accepted work in the app and campaign; do not assume a club submission transfers rights. Keep an internal alternate vector version in case delivery misses the cutoff.
5. **AI-assisted sketches:** use only for mood exploration and silhouette thumbnails, never final production or a “near-copy” of reference games. Human artist redraws selected concept from scratch as original vector. Avoid student likenesses and identifiable real people.

| Asset class | Format / budget target | Runtime notes |
|---|---|---|
| Mascots, icons, frames | SVG source; rendered vector or optimized WebP/PNG fallback. Aim ≤20 KB per simple SVG, ≤80 KB per 2x raster character. | No embedded bitmap textures; keep paths concise. |
| Rive character | `.riv`, target ≤250 KB per character file. | One mascot instance visible; pause when offscreen; test on 2–3 GB devices. |
| Lottie effect | `.json`/`.lottie`, target ≤120 KB per effect. | Short, no huge image layers, no dozens of masks. |
| Share card | Rendered on demand, 1080×1350 PNG or JPEG, target <500 KB. | No bundled per-student portrait required. |
| Sound | Original mono `.ogg`/`.m4a`, 44.1 kHz, ≤40 KB per cue where practical. | Short cues; lazy-load or bundle only the small core set. |

### 20/11 asset minimum

Ship 20/11 with Mướp in three poses, Sen event host portrait, one original event header illustration, 3 rarity card frames (shared vector geometry + tokens/patterns), and one small claim/level-up effect. Use a single reusable cosmetic set of 3–5 items; do not block the event on a full mascot animation rig. Source art must be committed before any asset ship, per project process.

## 7. Phased build order

Rough effort assumes one Flutter engineer plus part-time designer/illustrator; S ≈ 1–3 days, M ≈ 4–8 days, L ≈ 2+ weeks. Product API/data support is not included in art effort and is a dependency to confirm before implementation.

### Slice A — 20 November 2026: small, complete-feeling event

| Item | Effort | Notes |
|---|:---:|---|
| Pocket Journal token mapping + lobby hierarchy, mascot art and three static poses | M | Keep token additions minimal; no new dependency required. |
| 20/11 event page with short story chain and original “Tri ân Thầy Cô” cosmetic set | M | Respectful optional participation; avoid public teacher ratings or compulsory messages. |
| Reuse quest flow for event/daily card, cosmetic-only claim, clear XP feedback | M | Reuse `QuestCard` mechanics; visual refresh and claim effect. |
| XP bar and level badge presentation; plan for level range 1–50 | S | UI only if the progression API exists; otherwise show available data and defer live levels. |
| Collection book preview with earned items and a small `???` set | S | Discovery only; no paid/random purchase. |
| Claim / level-up / cosmetic equip micro-juice, reduced-motion behavior | S | Flutter implicit animations first. |
| Share card preview with level, frame, title, mascot and privacy-safe fields | M | Export/share only after confirming existing platform share capability. |

**Slice A success shape:** from lobby, a student understands the event, completes one optional quest, sees a cosmetic reward, equips it, and can make a privacy-safe share image. If XP/event APIs are not ready, present a clearly labeled event progress/reward path backed by existing functionality; do not invent client-only balances as production truth.

### Slice B — semester loop

| Item | Effort | Notes |
|---|:---:|---|
| Full free 30-tier “Sổ Hành Trình” screen and reward previews | L | Depends on season/tier state from product APIs. |
| XP/level progression polish through 1–50, level milestone cosmetics | M | Tie every milestone to cosmetic-only rewards. |
| Daily/weekly quest board and empty/refresh states | M | Keep tasks short and optional. |
| Full collection filters, rarity labels, item details, silhouette discovery | M | Token/pattern accessibility for rarity. |
| Remaining cast poses and limited Rive/Lottie loops | M | Budget for low-end device checks. |

### Slice C — collection and community depth

| Item | Effort | Notes |
|---|:---:|---|
| Campus QR hunt with clue map, fallback flow, and location-safe messaging | L | Optional, non-attendance, no public location history. |
| New-student story chains and orientation event set | M | Narrative pages are brief and skippable. |
| Chest opening, transparent rarity/pity explanation, item duplicate policy | L | Only if product rules and APIs are defined; no paid opening or sale. |
| Streak system, streak-freeze UX, compassionate recovery states | M | Needs explicit rules and API; never imply attendance/academic consequence. |
| Seasonal event kit and share-card templates | M | Original art, token-backed themes, privacy review. |

## 8. Open questions for the owner

Each answer can be one word.

1. **Direction:** `Journal`, `Arcade`, or `Folk`?
2. **Mascot:** approve `Mướp` as lead? `Yes` / `No`?
3. **Event:** should the 20/11 story be `Student-led` or `Campus-led`?
4. **Share card:** include the student’s `Name` or `Nickname`?
5. **Motion default:** `Standard` or `Reduced`?

## Source notes

- Game references are linked above to official game pages/help centers where available; use them to study interaction patterns only.
- Rive runtime license: [official runtime overview](https://github.com/rive-app/help-center/blob/master/runtimes/overview.md). Lottie Flutter package license: [pub.dev license page](https://pub.dev/packages/lottie/license). Check exact versions and authoring-tool terms before adding dependencies or production assets.
- Current code references inspected: `lib/features/infinite/quest.dart`, `infinite_view_model.dart`, `infinite_screen.dart`, `widgets/lobby_hero.dart`, `widgets/cosmetic_avatar.dart`, `widgets/quest_card.dart`, and `lib/theme/vd_tokens.dart`.
