/// T1: CRM pages a teacher may open inside the app through a one-use pass
/// (server design `lane-server-2026-11-16.md` §11, contract
/// `contract-web-pass.md`). The app only ever asks for these fixed relative
/// paths; ids are checked so nothing from a push payload can steer the pass.
library;

class CrmTarget {
  final String path;
  final Map<String, String> query;
  const CrmTarget._(this.path, [this.query = const {}]);

  /// "Việc của tôi" (CRM Công việc).
  static const tasksPath = '/tasks';

  /// "Nhóm" (CRM group boards).
  static const groupsPath = '/nhom';

  static const allowedPaths = {tasksPath, groupsPath};

  static final RegExp _id = RegExp(r'^[A-Za-z0-9-]{1,64}$');

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
      _ => null,
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

  String get title => path == tasksPath ? 'Việc của tôi' : 'Nhóm';
}
