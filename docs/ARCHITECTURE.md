# Architecture

The app follows Flutter's recommended MVVM layering:

- **Views** (`*_screen.dart`, `widgets/`) render state and forward user events.
- **ViewModels** (`*_view_model.dart`) extend `ChangeNotifier` and hold screen state.
- **Repositories** (`lib/data/`) are the only place a view model gets data from.
- **Services** (`lib/services/`: `EmsApiService`, `CrmStudentApi`, `CrmTeacherApi`) do the HTTP work.

```
lib/
  core/                     shared helpers with no feature knowledge
  data/                     repositories wrapping the services
  features/<feature>/
    <feature>_view_model.dart
    <feature>_screen.dart
    widgets/                big UI blocks of that screen
  theme/                    VdColors and ThemeData (the only colour source)
```

Legacy code still lives in `lib/screens`, `lib/services`, `lib/models`; features
are migrated into `lib/features` one at a time.

## Rules (enforced by `test/architecture_guard_test.dart`)

1. A Dart file in `lib/` is at most 400 lines. Screens under `lib/features` are at
   most 250 lines, files in a feature's `widgets/` at most 200. Existing
   offenders sit in an allowlist that may only shrink: a listed file must never
   grow, and an entry is removed when its file is split or migrated.
2. View models import only `package:flutter/foundation.dart`. Never
   `material.dart` or `widgets.dart`, so they stay testable without a widget tree.
3. View models receive their repositories through the constructor. No singletons
   or static calls inside a view model.
4. Views (`*_screen.dart` and everything in `widgets/`) never reference
   `EmsApiService`, `CrmStudentApi` or `CrmTeacherApi`. They talk to the view model.
5. Navigator, dialogs, snackbars and `BuildContext` stay in views. A view model
   exposes a flag (for example a 401 flag) and the view reacts to it, e.g. via
   `handleCrmAuthError`.
6. Colours come only from `lib/theme` (`VdColors`) or `Theme.of(context)`.
   Screens migrated with hard-coded colours keep them verbatim until a
   dedicated, visible restyle step replaces them.
7. Money, grades and attendance values are displayed exactly as the server
   sends them. No client-side recomputation, rounding changes or "fixing".

## Adding a feature

1. Create `lib/data/<feature>_repository.dart` wrapping the service calls.
2. Create the view model (state, refresh, error flags) with a unit test using a
   fake repository.
3. Create the screen with `ListenableBuilder` and split large blocks into `widgets/`.
4. Write a characterization test against the OLD screen before moving code, and
   keep it unchanged after the move.
5. Remove the old file from the guard allowlist.
