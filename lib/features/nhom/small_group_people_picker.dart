part of 'small_group_screens.dart';

/// Pick people from the directory (search by name, sign-in name or code). Returns user ids → names.
class PeoplePicker extends StatefulWidget {
  final bool work;
  final String title;
  final bool single;

  /// Most people that can be ticked; a further tap says so (null: no limit).
  final int? max;
  const PeoplePicker({
    super.key,
    this.work = true,
    required this.title,
    this.single = false,
    this.max,
  });

  @override
  State<PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<PeoplePicker> {
  List<Map<String, dynamic>>? _all;
  final Map<String, String> _picked = {};
  String _q = '';
  bool _failed = false;
  bool _full = false;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> _usable(List<Map<String, dynamic>> p) {
    final me = AppSession.instance.userId;
    return p
        .where(
          (x) =>
              '${x['id']}' != me &&
              (!widget.work || x['can_receive_work'] != false),
        )
        .toList();
  }

  void _loadPeople() {
    SmallGroupApi.people(work: widget.work)
        .then((p) {
          if (mounted) setState(() => _all = _usable(p));
        })
        .catchError((e) async {
          if (!mounted) return;
          setState(() => _failed = true);
          await _fail(context, e);
        });
  }

  // The server's `?q=` (name, sign-in name, account or teacher code, khoa)
  // answers what was typed; the local list shows matches meanwhile.
  Timer? _debounce;
  List<Map<String, dynamic>>? _found;
  String _foundFor = '';

  void _search(String v) {
    setState(() => _q = v.trim());
    _debounce?.cancel();
    final q = _q;
    if (q.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final p = await SmallGroupApi.people(work: widget.work, q: q);
        if (mounted && _q == q) {
          setState(() {
            _found = _usable(p);
            _foundFor = q;
          });
        }
      } catch (_) {
        // The local list stays; a failed search is not worth a message.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final server = _q.length >= 2 && _foundFor == _q ? _found : null;
    final rows = (server ?? _all ?? const <Map<String, dynamic>>[])
        .where(
          (p) =>
              server != null ||
              _q.length < 2 ||
              _foldVi(
                '${p['full_name']} ${p['hint'] ?? ''}',
              ).contains(_foldVi(_q)),
        )
        .take(60)
        .toList();
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (!widget.single)
            TextButton(
              onPressed: _picked.isEmpty
                  ? null
                  : () => Navigator.pop(context, _picked),
              child: Text(
                'Xong (${_picked.length})',
                style: TextStyle(color: vd.onHeader),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Gõ tên, tên đăng nhập hoặc mã (ít nhất 2 chữ)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _search,
            ),
          ),
          if (_picked.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final e in _picked.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InputChip(
                        label: Text(e.value),
                        onDeleted: () => setState(() {
                          _picked.remove(e.key);
                          _full = false;
                        }),
                      ),
                    ),
                ],
              ),
            ),
          if (_full)
            Text(
              'Đã chọn đủ số người tối đa cho lần này.',
              style: TextStyle(color: vd.danger, fontSize: 13),
            ),
          Expanded(
            child: _all == null
                ? (_failed
                      ? LoadError(
                          message: 'Không tải được danh sách người.',
                          onRetry: () {
                            setState(() => _failed = false);
                            _loadPeople();
                          },
                        )
                      : const Center(child: CircularProgressIndicator()))
                : ListView(
                    children: [
                      for (final p in rows)
                        ListTile(
                          title: Text('${p['full_name'] ?? ''}'),
                          subtitle: Text(
                            '${p['role_label'] ?? p['role'] ?? ''}${p['hint'] != null ? ' · ${p['hint']}' : ''}',
                          ),
                          trailing: _picked.containsKey('${p['id']}')
                              ? Icon(Icons.check_circle, color: vd.accent)
                              : null,
                          onTap: () {
                            final id = '${p['id']}';
                            if (widget.single) {
                              Navigator.pop(context, {
                                id: '${p['full_name'] ?? ''}',
                              });
                              return;
                            }
                            setState(() {
                              if (_picked.containsKey(id)) {
                                _picked.remove(id);
                                _full = false;
                              } else if (widget.max != null &&
                                  _picked.length >= widget.max!) {
                                _full = true;
                              } else {
                                _picked[id] = '${p['full_name'] ?? ''}';
                              }
                            });
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// "hoang tho" finds "Hoàng Thơ": search ignores Vietnamese marks. The
// sign-in name and teacher code ride in `hint`, so "manhdung" finds them.
const _viFrom =
    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _viTo =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
String _foldVi(String s) {
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = _viFrom.indexOf(ch);
    b.write(i >= 0 ? _viTo[i] : ch);
  }
  return b.toString();
}
