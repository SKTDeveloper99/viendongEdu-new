import 'package:flutter/material.dart';
import '../models/crm_identity.dart';
import '../services/app_session.dart';
import '../services/ems_api_service.dart';
import '../utils/snack.dart';
import '../data/api/auth_api.dart';
import '../theme/vd_tokens.dart';
import '../core/password_policy.dart';

/// Đổi mật khẩu CRM. Dùng cho CẢ HAI trường hợp:
///  - lối vào "Đổi mật khẩu" bình thường trong app (`forced: false`, mặc định);
///  - đổi mật khẩu BẮT BUỘC ngay sau khi đăng nhập lần đầu, khi
///    `must_change_password` là true (`forced: true` — không có nút back,
///    thành công thì đi thẳng vào app thay vì pop về màn trước).
class ChangePasswordScreen extends StatefulWidget {
  final bool forced;
  const ChangePasswordScreen({super.key, this.forced = false});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _loading = false;

  /// Server refusal, shown above the button (a top snackbar hides behind
  /// the keyboard — owner report 2026-10-14).
  String? _error;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isTeacher = AppSession.instance.role == CrmRole.teacher;
      final current = _oldCtrl.text.trim();
      final next = _newCtrl.text.trim();
      if (isTeacher) {
        final freshToken = await AuthApi.changeTeacherPassword(
          currentPassword: current,
          newPassword: next,
        );
        if (freshToken != null) AppSession.instance.emsToken = freshToken;
      } else {
        await AuthApi.changeStudentPassword(
          currentPassword: current,
          newPassword: next,
        );
      }
      AppSession.instance.mustChangePassword = false;
      await AppSession.instance.persist();
      if (!mounted) return;
      showSuccessSnack(context, 'Đổi mật khẩu thành công!');
      if (widget.forced) {
        final route = isTeacher ? '/gv_home' : '/home';
        Navigator.pushReplacementNamed(context, route);
      } else {
        Navigator.pop(context);
      }
    } on EmsException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Không kết nối được máy chủ. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Bắt buộc đổi mật khẩu: không cho back ra ngoài trước khi xong.
      canPop: !widget.forced,
      child: Scaffold(
        backgroundColor: context.vd.bg,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [context.vd.primary, context.vd.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    if (!widget.forced)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.arrow_back_ios,
                          color: context.vd.onPrimary,
                          size: 20,
                        ),
                      ),
                    if (!widget.forced) const SizedBox(width: 8),
                    Text(
                      widget.forced ? 'Vui lòng đổi mật khẩu' : 'Đổi mật khẩu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.vd.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: context.vd.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: context.vd.shadow,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _PassField(
                                controller: _oldCtrl,
                                label: 'Mật khẩu hiện tại',
                                show: _showOld,
                                onToggle: () =>
                                    setState(() => _showOld = !_showOld),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Vui lòng nhập mật khẩu hiện tại.'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _PassField(
                                controller: _newCtrl,
                                label: 'Mật khẩu mới',
                                show: _showNew,
                                onToggle: () =>
                                    setState(() => _showNew = !_showNew),
                                validator: (v) {
                                  return newPasswordProblem(
                                    v ?? '',
                                    current: _oldCtrl.text.trim(),
                                    mssv: AppSession.instance.mssv,
                                    student:
                                        AppSession.instance.role !=
                                        CrmRole.teacher,
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _PassField(
                                controller: _confirmCtrl,
                                label: 'Xác nhận mật khẩu mới',
                                show: _showConfirm,
                                onToggle: () => setState(
                                  () => _showConfirm = !_showConfirm,
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Vui lòng xác nhận mật khẩu mới.';
                                  }
                                  if (v != _newCtrl.text) {
                                    return 'Vui lòng nhập lại mật khẩu xác nhận cho khớp';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Mật khẩu mới: ít nhất 8 ký tự, có cả chữ và số, '
                          'không chứa mã số sinh viên.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.vd.inkMuted,
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: context.vd.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.vd.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                            ),
                            child: _loading
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: context.vd.onPrimary,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    'Xác nhận đổi mật khẩu',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: context.vd.onPrimary,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool show;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PassField({
    required this.controller,
    required this.label,
    required this.show,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: !show,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 14),
        prefixIcon: Icon(Icons.lock_outline, color: context.vd.primary),
        suffixIcon: IconButton(
          icon: Icon(
            show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: context.vd.inkFaint,
            size: 20,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.vd.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
