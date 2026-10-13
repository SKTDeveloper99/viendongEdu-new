# Viễn Đông app (viendongEdu-new)

Flutter student/teacher app for Cao đẳng Viễn Đông. It reads the CRM and EMS
APIs; the CRM repo (crm-clean) and its law book own all domain rules. UI is
Vietnamese. This repo is public: never commit keys, tokens, `.env` files or
student data.

- **Never build or change the version** (`flutter build`, `bump.sh`, the
  `version:` line in `pubspec.yaml`) unless the owner says so in that message.
  Prepare code, run analyze and tests, then stop and ask.
- Read only the files the task touches. `build/` and `.dart_tool/` are
  generated; never read them.
- Layout and rules: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (MVVM:
  `lib/features/<feature>/` view + view model, `lib/data/` repositories,
  `lib/services/` HTTP, `lib/theme/` colours). Legacy code in `lib/screens`.
- Money, grades and attendance are shown exactly as the server sends them.
- Check: `flutter analyze` and `flutter test --exclude-tags golden`
  (`test/architecture_guard_test.dart` enforces file sizes and layering).
- Work on a branch from `main` and open a PR.
