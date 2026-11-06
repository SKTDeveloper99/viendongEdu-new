import 'package:flutter/material.dart';

import '../../../data/class_manager_repository.dart';
import '../class_manager_format.dart';
import '../class_manager_models.dart';
import '../session_detail_view_model.dart';
import 'class_manager_state_views.dart';
import 'session_student_list.dart';
import '../../../theme/vd_tokens.dart';

/// Opens the session detail bottom sheet (75% of the screen height).
void showSessionDetailSheet(
  BuildContext context, {
  required ClassManagerRepository repository,
  required SessionGroup session,
  required String? sessionKey,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.75,
      child: SessionDetailSheet(
        repository: repository,
        session: session,
        sessionKey: sessionKey,
      ),
    ),
  );
}

/// Who was present / absent / not yet marked in one session (EMS marks).
class SessionDetailSheet extends StatefulWidget {
  final ClassManagerRepository repository;
  final SessionGroup session;
  final String? sessionKey;
  const SessionDetailSheet({
    super.key,
    required this.repository,
    required this.session,
    required this.sessionKey,
  });

  @override
  State<SessionDetailSheet> createState() => _SessionDetailSheetState();
}

class _SessionDetailSheetState extends State<SessionDetailSheet> {
  late final SessionDetailViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = SessionDetailViewModel(
      widget.repository,
      session: widget.session,
      sessionKey: widget.sessionKey,
    )..load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.session;
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => SheetFrame(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmtDate(b.date),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${b.startTime ?? ''} – ${fmtTime(b.endTime)}',
                      style: TextStyle(fontSize: 13, color: context.vd.inkMuted),
                    ),
                  ],
                ),
                const Spacer(),
                if (!_vm.loading && _vm.error == null) ...[
                  _StatPill(
                    label: 'Có mặt',
                    value: _vm.presentCount,
                    color: context.vd.success,
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    label: 'Vắng',
                    value: _vm.absentCount,
                    color: context.vd.danger,
                  ),
                  _StatPill(
                    label: 'Chưa ĐD',
                    value: _vm.unmarkedCount,
                    color: context.vd.info,
                  ),
                ] else ...[
                  Text(
                    'Sĩ số: ${_vm.students.length}',
                    style: TextStyle(fontSize: 13, color: context.vd.inkMuted),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: context.vd.hairline),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_vm.loading) return const SheetLoading();
    final error = _vm.error;
    if (error != null) return SheetErrorView(message: error, onRetry: _vm.load);
    final students = _vm.students;
    if (students.isEmpty) {
      return Center(
        child: Text('Không có học viên', style: TextStyle(color: context.vd.inkMuted)),
      );
    }
    return SessionStudentList(vm: _vm);
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: color)),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
