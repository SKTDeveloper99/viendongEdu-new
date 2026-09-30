import 'package:flutter/material.dart';

import '../../../data/class_manager_repository.dart';
import '../../../models/crm_teacher_class.dart';
import '../../../services/crm_session_guard.dart';
import '../class_detail_sheet_view_model.dart';
import 'class_attendance_tab.dart';
import 'class_info_tab.dart';
import 'class_manager_state_views.dart';
import 'class_students_tab.dart';
import '../../../theme/vd_tokens.dart';

/// Opens the class detail bottom sheet (85% of the screen height).
void showClassDetailSheet(
  BuildContext context, {
  required ClassManagerRepository repository,
  required CrmTeacherClass lop,
  required String? lmhId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SizedBox(
      height: MediaQuery.of(ctx).size.height * 0.85,
      child: ClassDetailSheet(repository: repository, lop: lop, lmhId: lmhId),
    ),
  );
}

/// Tabs "Thông tin" / "Danh sách" / "Điểm danh" of one class.
class ClassDetailSheet extends StatefulWidget {
  final ClassManagerRepository repository;
  final CrmTeacherClass lop;
  final String? lmhId;
  const ClassDetailSheet({
    super.key,
    required this.repository,
    required this.lop,
    required this.lmhId,
  });

  @override
  State<ClassDetailSheet> createState() => _ClassDetailSheetState();
}

class _ClassDetailSheetState extends State<ClassDetailSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ClassDetailSheetViewModel _vm;
  bool _authHandled = false;

  @override
  void initState() {
    super.initState();
    _vm = ClassDetailSheetViewModel(
      widget.repository,
      lop: widget.lop,
      lmhId: widget.lmhId,
    )..addListener(_onChanged);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => _vm.onTabSelected(_tabController.index));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _vm.removeListener(_onChanged);
    _vm.dispose();
    super.dispose();
  }

  // A 401 clears the session and returns to the login screen.
  void _onChanged() {
    if (!_vm.unauthorized) {
      _authHandled = false;
      return;
    }
    if (_authHandled || !mounted) return;
    _authHandled = true;
    handleCrmAuthError(context, _vm.authError!);
  }

  @override
  Widget build(BuildContext context) {
    final lop = widget.lop;
    return SheetFrame(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lop.subjectName ?? '',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lop.subjectCode ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.vd.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TabBar(
          controller: _tabController,
          labelColor: context.vd.primary,
          unselectedLabelColor: context.vd.inkMuted,
          indicatorColor: context.vd.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Thông tin'),
            Tab(text: 'Danh sách'),
            Tab(text: 'Điểm danh'),
          ],
        ),
        Divider(height: 1, color: context.vd.hairline),
        Expanded(
          child: ListenableBuilder(
            listenable: _vm,
            builder: (context, _) => TabBarView(
              controller: _tabController,
              children: [
                ClassInfoTab(lop: lop),
                ClassStudentsTab(vm: _vm),
                ClassAttendanceTab(vm: _vm, repository: widget.repository),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
