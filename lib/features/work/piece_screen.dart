import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/app_session.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_motion.dart';
import '../../theme/vd_tokens.dart';
import '../../utils/snack.dart';
import 'work_api.dart';
import '../nhom/nhom_screens.dart';
import '../nhom/small_group_api.dart';
import '../nhom/small_group_screens.dart';

part 'piece_screen_parts_1.dart';
part 'piece_screen_parts_2.dart';
part 'piece_screen_parts_3.dart';

/// One piece of work on ONE screen (Overlord slice): what it is, where it
/// came from (a calendar line, a Nhóm), its files, each person's part with
/// Duyệt / Trả lại / Nhắc for the giver, the receiver's own moves, and the
/// conversation. Every list, bell and line opens this same screen.
class PieceScreen extends StatefulWidget {
  final String taskId;
  const PieceScreen({super.key, required this.taskId});

  @override
  State<PieceScreen> createState() => _PieceScreenState();
}

class _PieceScreenState extends State<PieceScreen> {
  Map<String, dynamic>? _task;

  List<Map<String, dynamic>> _comments = const [];

  String? _error;

  bool _busy = false;

  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  // ── Action effects (Overlord home, agreed 2026-11-16) ─────────────────────
  // Each action button shows progress while its request runs, then a check
  // with a haptic; a person whose part is settled leaves the list over 200 ms
  // instead of the whole list jumping; a failure says what happened in one
  // line with "Thử lại". All durations come from VdMotion (zero under Reduce
  // Motion).
  final Map<String, String> _act = {}; // key → busy | done | error message

  final Map<String, Future<void> Function()> _retry = {};

  final Set<String> _leaving = {};

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return Scaffold(
      backgroundColor: vd.bg,
      appBar: AppBar(title: const Text('Một việc')),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : _task == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: AbsorbPointer(absorbing: _busy, child: _body(vd)),
            ),
    );
  }

  // Lets the extensions in this library's parts call setState.
  void _set(VoidCallback f) => setState(f);
}
