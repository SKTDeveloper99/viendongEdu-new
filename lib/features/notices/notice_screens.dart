import 'package:flutter/material.dart';

import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import '../nhom/nhom_screens.dart';
import '../nhom/small_group_screens.dart' show PeoplePicker;
import '../work/piece_screen.dart';
import '../work/work_api.dart';

part 'notice_screens_parts_1.dart';

/// "Gửi thông báo" (Overlord; server `routes/notices.js`). One sentence to one
/// person (always a phone banner) or to a place: a Nhóm, a calendar line, a
/// khoa, up to 20 picked people, or the whole school for admin/vice admin.
/// To many, "Thường" rings nobody (bell and badge only); "Cần xem ngay" is a
/// banner, chosen on purpose, with a daily cap the server sets.
abstract final class NoticeApi {
  static Future<Map<String, dynamic>> targets() =>
      EmsApiService.sendMap('GET', '/notices/targets');
  static Future<Map<String, dynamic>> send(Map<String, dynamic> body) =>
      EmsApiService.sendMap('POST', '/notices', body: body);
  static Future<Map<String, dynamic>> sent() =>
      EmsApiService.sendMap('GET', '/notices/sent');
  static Future<Map<String, dynamic>> one(String id) =>
      EmsApiService.sendMap('GET', '/notices/$id');
  static Future<Map<String, dynamic>> resend(String id) =>
      EmsApiService.sendMap('POST', '/notices/$id/resend');
}

Future<void> _fail(BuildContext context, Object e) async {
  if (e is EmsException && e.statusCode == 401) {
    await handleCrmAuthError(context, e);
    return;
  }
  if (context.mounted)
    showErrorSnack(
      context,
      e is EmsException ? e.message : 'Không kết nối được máy chủ.',
    );
}

String _scopeLabel(String? k) => switch (k) {
  'person' => 'Một người',
  'people' => 'Chọn người',
  'space' => 'Nhóm',
  'line' => 'Dòng lịch',
  'khoa' => 'Khoa',
  'school' => 'Toàn trường',
  _ => '',
};

class NoticeComposeScreen extends StatefulWidget {
  /// Preset place (e.g. from a Nhóm): {'kind': 'space', 'id': …, 'name': …}.
  final Map<String, String>? preset;
  const NoticeComposeScreen({super.key, this.preset});

  @override
  State<NoticeComposeScreen> createState() => _NoticeComposeScreenState();
}

class _NoticeComposeScreenState extends State<NoticeComposeScreen> {
  Map<String, dynamic>? _t;

  String _kind = 'person';

  String? _placeId;

  String? _placeName;

  Map<String, String> _people = {};

  bool _urgent = false;

  bool _busy = false;

  final _body = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = widget.preset;
    if (p != null) {
      _kind = p['kind'] ?? 'person';
      _placeId = p['id'];
      _placeName = p['name'];
    }
    NoticeApi.targets()
        .then((t) {
          if (mounted) setState(() => _t = t);
        })
        .catchError((e) async {
          if (mounted) await _fail(context, e);
        });
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final kinds = [
      'person',
      'space',
      'line',
      'khoa',
      'people',
      if (_t?['school'] == true) 'school',
    ];
    final ready = _to != null && _body.text.trim().isNotEmpty && !_busy;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(
        title: const Text('Gửi thông báo'),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SentNoticesScreen()),
            ),
            child: Text('Đã gửi', style: TextStyle(color: vd.onHeader)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'GỬI CHO',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w700,
              color: vd.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final k in kinds)
                ChoiceChip(
                  label: Text(_scopeLabel(k)),
                  selected: _kind == k,
                  onSelected: (_) => setState(() {
                    _kind = k;
                    _placeId = null;
                    _placeName = null;
                    _people = {};
                    _urgent = false;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_kind == 'person' || _kind == 'people')
            OutlinedButton.icon(
              onPressed: _pickPeople,
              icon: const Icon(Icons.person_add_alt),
              label: Text(
                _people.isEmpty
                    ? (_kind == 'person'
                          ? 'Chọn người'
                          : 'Chọn người (tối đa 20)')
                    : _people.values.join(', '),
                overflow: TextOverflow.ellipsis,
              ),
            )
          else if (_kind != 'school')
            OutlinedButton.icon(
              onPressed: _t == null ? null : _pickPlace,
              icon: const Icon(Icons.place_outlined),
              label: Text(
                _placeName ?? 'Chọn ${_scopeLabel(_kind).toLowerCase()}',
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            Text(
              'Mọi cán bộ, giảng viên đang làm việc.',
              style: TextStyle(color: vd.inkMuted),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Nội dung (một câu)',
              border: OutlineInputBorder(),
            ),
          ),
          Text(
            'Mỗi người nhận có chuông trên điện thoại và một dòng trong mục Thông báo.',
            style: TextStyle(color: context.vd.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: ready ? _send : null,
            child: Text(_busy ? 'Đang gửi…' : 'Gửi'),
          ),
        ],
      ),
    );
  }

  // Lets the extensions in this library's parts call setState.
  void _set(VoidCallback f) => setState(f);
}

extension _NoticeComposeScreenStatePart1 on _NoticeComposeScreenState {
  bool get _many => _kind != 'person';

  int get _urgentLeft => asInt(_t?['urgent_left_today']);

  List<Map<String, dynamic>> _list(String k) =>
      ((_t?[k] as List?) ?? const []).cast<Map<String, dynamic>>();

  Map<String, dynamic>? get _to => switch (_kind) {
    'person' =>
      _people.isEmpty ? null : {'kind': 'person', 'id': _people.keys.first},
    'people' =>
      _people.isEmpty ? null : {'kind': 'people', 'ids': _people.keys.toList()},
    'school' => {'kind': 'school'},
    _ => _placeId == null ? null : {'kind': _kind, 'id': _placeId},
  };

  Future<void> _send({int? confirm}) async {
    final to = _to;
    if (to == null || _body.text.trim().isEmpty) return;
    _set(() => _busy = true);
    try {
      final r = await NoticeApi.send({
        'body': _body.text.trim(),
        'to': to,
        'confirm_count': ?confirm,
      });
      if (!mounted) return;
      final n = (r['notice'] as Map?) ?? const {};
      final skipped = asInt(r['skipped']);
      showSuccessSnack(
        context,
        'Đã gửi cho ${n['recipient_count']} người'
        '${skipped > 0 ? ' ($skipped người ngoài phạm vi bạn được gửi)' : ''}.',
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => NoticeDetailScreen(id: '${n['id']}')),
      );
    } on EmsException catch (e) {
      if (!mounted) return;
      if (e.code == 'confirm_count' ||
          (e.statusCode == 409 && e.message.startsWith('Gửi cho'))) {
        final count =
            int.tryParse(
              RegExp(r'\d+').firstMatch(e.message)?.group(0) ?? '',
            ) ??
            0;
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(e.message),
            content: Text('Mỗi người sẽ nhận chuông trên điện thoại.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Thôi'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Gửi cho $count người'),
              ),
            ],
          ),
        );
        if (ok == true) {
          _set(() => _busy = false);
          await _send(confirm: count);
          return;
        }
      } else {
        await _fail(context, e);
      }
    } catch (e) {
      if (mounted) await _fail(context, e);
    } finally {
      if (mounted) _set(() => _busy = false);
    }
  }

  Future<void> _pickPlace() async {
    final items = switch (_kind) {
      'space' =>
        _list('spaces')
            .map((s) => ('${s['id']}', '${s['name']}', '${s['members']} người'))
            .toList(),
      'line' =>
        _list('lines')
            .map(
              (l) => (
                '${l['id']}',
                '${l['content']}',
                '${l['day'] ?? ''}'.split('T').first,
              ),
            )
            .toList(),
      'khoa' =>
        _list('khoa')
            .map((k) => ('${k['id']}', '${k['name']}', '${k['people']} người'))
            .toList(),
      _ => <(String, String, String)>[],
    };
    final r = await showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              if (items.isEmpty)
                const ListTile(title: Text('Không có mục nào.')),
              for (final i in items)
                ListTile(
                  title: Text(
                    i.$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(i.$3),
                  onTap: () => Navigator.pop(ctx, (i.$1, i.$2)),
                ),
            ],
          ),
        ),
      ),
    );
    if (r != null)
      _set(() {
        _placeId = r.$1;
        _placeName = r.$2;
      });
  }

  Future<void> _pickPeople() async {
    final r = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => PeoplePicker(
          work: false,
          title: _kind == 'person' ? 'Gửi cho ai?' : 'Chọn tối đa 20 người',
          single: _kind == 'person',
        ),
      ),
    );
    if (r == null) return;
    _set(() {
      _people = _kind == 'person' ? r : {..._people, ...r};
      if (_people.length > 20)
        _people = Map.fromEntries(_people.entries.take(20));
    });
  }
}

/// What I sent, with "đã xem x/y".
class SentNoticesScreen extends StatefulWidget {
  const SentNoticesScreen({super.key});

  @override
  State<SentNoticesScreen> createState() => _SentNoticesScreenState();
}
