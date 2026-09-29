import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'app_session.dart';

/// A small, account-scoped disk snapshot for read-only home and help screens.
/// The server remains authoritative. Callers must label snapshots as old and
/// refresh them when a connection is available.
class OfflineSnapshot {
  OfflineSnapshot._();

  static String? get _scope {
    final session = AppSession.instance;
    final id = session.isGiangVien ? session.teacherId : session.mssv;
    if (!session.hasEms || id == null || id.isEmpty) return null;
    return base64Url.encode(utf8.encode('${session.role}:$id'));
  }

  static String? _key(String resource) {
    final scope = _scope;
    if (scope == null) return null;
    return 'offline_v1_${scope}_${base64Url.encode(utf8.encode(resource))}';
  }

  static Future<void> save(String resource, Object data) async {
    final key = _key(resource);
    if (key == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        key,
        jsonEncode({
          'saved_at': DateTime.now().toUtc().toIso8601String(),
          'data': data,
        }),
      );
    } catch (_) {
      // Disk storage must never turn a successful server read into a failure.
    }
  }

  static Future<OfflineValue?> load(String resource) async {
    final key = _key(resource);
    if (key == null) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(map['saved_at']?.toString() ?? '');
      if (savedAt == null) return null;
      return OfflineValue(map['data'], savedAt.toLocal());
    } catch (_) {
      return null;
    }
  }

  /// Call before clearing the session so another account cannot inherit data.
  static Future<void> clearCurrentAccount() async {
    final scope = _scope;
    if (scope == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where(
        (key) => key.startsWith('offline_v1_${scope}_'),
      )) {
        await prefs.remove(key);
      }
    } catch (_) {
      // A storage failure must not prevent the account from signing out.
    }
  }
}

class OfflineValue {
  final dynamic data;
  final DateTime savedAt;
  const OfflineValue(this.data, this.savedAt);
}
