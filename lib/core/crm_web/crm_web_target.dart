/// T1: CRM pages a teacher may open inside the app through a one-use pass
/// (server design `lane-server-2026-11-16.md` §11, contract
/// `contract-web-pass.md`). The app only ever asks for these fixed relative
/// paths; ids are checked so nothing from a push payload can steer the pass.
library;

class CrmTarget {
  final String path;
  final Map<String, String> query;

  /// The title the home gave this page (server-led home, proposed P-50).
  final String? label;
  const CrmTarget._(this.path, [this.query = const {}, this.label]);

  /// "Việc của tôi" (CRM Công việc).
  static const tasksPath = '/tasks';

  /// "Nhóm" (CRM group boards).
  static const groupsPath = '/nhom';

  /// Viva pages inside the app for office accounts (Overlord slice).
  static const weekPath = '/lich-tuan';
  static const congVanPath = '/cong-van';
  static const workLogPath = '/nhat-ky';
  static const studentsPath = '/sinh-vien';
  static const vivaPath = '/viva';

  static const allowedPaths = {
    tasksPath,
    groupsPath,
    weekPath,
    congVanPath,
    workLogPath,
    studentsPath,
    vivaPath,
  };

  const CrmTarget.week() : this._(weekPath);
  const CrmTarget.congVan() : this._(congVanPath);
  const CrmTarget.workLog() : this._(workLogPath);
  const CrmTarget.students() : this._(studentsPath);
  const CrmTarget.viva() : this._(vivaPath);

  static final RegExp _id = RegExp(r'^[A-Za-z0-9-]{1,64}$');

  /// Proposed P-50: any other Viva page the server lists, by its relative
  /// path. Only a plain path passes (one leading slash, 1–4 segments of
  /// letters, digits, `_` and `-`); the server refuses a pass for a path it
  /// does not list, and the view loads only our own host.
  static final RegExp _pagePath = RegExp(r'^(?:/[A-Za-z0-9_-]{1,40}){1,4}$');

  static bool pagePathOk(String p) => p.length <= 120 && _pagePath.hasMatch(p);

  /// A page by its path ([allowedPaths] keep their own targets), or null.
  static CrmTarget? page(String path, {String? label}) {
    if (!pagePathOk(path)) return null;
    return fromRouteName('/crm$path')?.withLabel(label);
  }

  CrmTarget withLabel(String? l) =>
      l == null || l.isEmpty ? this : CrmTarget._(path, query, l);

  factory CrmTarget.tasks({String? taskId}) =>
      CrmTarget._(tasksPath, _ids({'task_id': taskId}));

  factory CrmTarget.groups({String? taskId, String? spaceId}) =>
      CrmTarget._(groupsPath, _ids({'task_id': taskId, 'space_id': spaceId}));

  static Map<String, String> _ids(Map<String, String?> raw) => {
    for (final e in raw.entries)
      if (e.value != null && _id.hasMatch(e.value!)) e.key: e.value!,
  };

  /// The relative target sent to the pass endpoint, e.g. `/tasks?task_id=7`.
  String get relative =>
      query.isEmpty ? path : Uri(path: path, queryParameters: query).toString();

  /// App route name for this page (`/crm/tasks?task_id=7`).
  String get routeName => '/crm$relative';

  /// Reads an app route name back; null for anything not allow-listed.
  static CrmTarget? fromRouteName(String name) {
    if (!name.startsWith('/crm/')) return null;
    final uri = Uri.tryParse(name.substring(4));
    if (uri == null) return null;
    final q = uri.queryParameters;
    return switch (uri.path) {
      tasksPath => CrmTarget.tasks(taskId: q['task_id']),
      groupsPath => CrmTarget.groups(
        taskId: q['task_id'],
        spaceId: q['space_id'],
      ),
      weekPath => const CrmTarget.week(),
      congVanPath => const CrmTarget.congVan(),
      workLogPath => const CrmTarget.workLog(),
      studentsPath => const CrmTarget.students(),
      vivaPath => const CrmTarget.viva(),
      _ =>
        uri.query.isEmpty && uri.fragment.isEmpty && pagePathOk(uri.path)
            ? CrmTarget._(uri.path)
            : null,
    };
  }

  /// A push payload from the CRM task notifier (`lib/tasks/notify.js`,
  /// `lib/spaces-spaces-service.js`): `route: '/tasks' | '/nhom'` with
  /// `task_id` / `space_id`. Teachers only; null otherwise.
  static CrmTarget? fromPush(
    Map<String, dynamic> data, {
    required bool isTeacher,
  }) {
    if (!isTeacher) return null;
    final taskId = data['task_id']?.toString();
    return switch (data['route']) {
      tasksPath => CrmTarget.tasks(taskId: taskId),
      groupsPath => CrmTarget.groups(
        taskId: taskId,
        spaceId: data['space_id']?.toString(),
      ),
      _ => null,
    };
  }

  String get title => label ?? _fixedTitle;

  String get _fixedTitle => switch (path) {
    tasksPath => 'Việc của tôi',
    weekPath => 'Lịch tuần',
    congVanPath => 'Công văn',
    workLogPath => 'Nhật ký làm việc',
    studentsPath => 'Tra cứu sinh viên',
    vivaPath => 'Viva',
    groupsPath => 'Nhóm',
    _ => 'Viva',
  };
}
