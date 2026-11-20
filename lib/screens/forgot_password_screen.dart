import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api/auth_api.dart';
import '../services/ems_api_service.dart';
import '../theme/vd_tokens.dart';

/// CÔNG TẮC DUY NHẤT cho dữ kiện thứ hai (ngày sinh). Nếu chủ trường quyết chỉ
/// cần MSSV, đặt `false`: ô ngày sinh biến mất và app chỉ gửi MSSV. Máy chủ có
/// công tắc tương ứng `REQUIRE_BIRTH_DATE` trong
/// lib/student-forgot-password-service.js (LAW P-51, đề xuất).
const bool kForgotPasswordAsksBirthDate = true;

/// "dd/mm/yyyy" (hoặc d/m/yyyy, dấu . hay -) → "yyyy-mm-dd"; null nếu không
/// phải một ngày có thật.
String? parseBirthDate(String raw) {
  final m = RegExp(r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$')
      .firstMatch(raw.trim());
  if (m == null) return null;
  final d = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final y = int.parse(m.group(3)!);
  final dt = DateTime.utc(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  String two(int v) => v.toString().padLeft(2, '0');
  return '$y-${two(mo)}-${two(d)}';
}

/// Học viên quên mật khẩu (chỉ học viên; cán bộ và giảng viên không có lối
/// này). Đúng MSSV và ngày sinh thì mật khẩu trở lại là MSSV; lần đăng nhập
/// sau app bắt đặt mật khẩu mới (màn hình đổi mật khẩu bắt buộc). Quay về
/// đăng nhập với MSSV vừa nhập ([Navigator.pop] trả về MSSV khi thành công).
class ForgotPasswordScreen extends StatefulWidget {
  final String initialMssv;
  const ForgotPasswordScreen({super.key, this.initialMssv = ''});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _mssvCtrl = TextEditingController(text: widget.initialMssv);
  final _dobCtrl = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _mssvCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parseBirthDate(_dobCtrl.text) != null
          ? DateTime.parse(parseBirthDate(_dobCtrl.text)!)
          : DateTime(now.year - 19),
      firstDate: DateTime(1940),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Chọn ngày sinh',
    );
    if (picked == null) return;
    String two(int v) => v.toString().padLeft(2, '0');
    setState(
      () => _dobCtrl.text =
          '${two(picked.day)}/${two(picked.month)}/${picked.year}',
    );
  }

  Future<void> _submit() async {
    final mssv = _mssvCtrl.text.trim();
    final dob = parseBirthDate(_dobCtrl.text);
    if (mssv.isEmpty ||
        (kForgotPasswordAsksBirthDate && _dobCtrl.text.trim().isEmpty)) {
      setState(
        () => _error = kForgotPasswordAsksBirthDate
            ? 'Vui lòng nhập mã số sinh viên và ngày sinh.'
            : 'Vui lòng nhập mã số sinh viên.',
      );
      return;
    }
    if (kForgotPasswordAsksBirthDate && dob == null) {
      setState(
        () => _error =
            'Ngày sinh chưa đúng dạng ngày/tháng/năm, ví dụ 09/03/2004.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final message = await AuthApi.forgotStudentPassword(
        mssv,
        dateOfBirth: kForgotPasswordAsksBirthDate ? dob : null,
      );
      if (!mounted) return;
      // The spinner stops before the dialog, not after it closes.
      setState(() => _sending = false);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Đã đặt lại mật khẩu'),
          content: Text(message),
          actions: [
            FilledButton(
              key: const Key('forgot-done'),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Về đăng nhập'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, mssv);
    } on EmsException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Đã có lỗi xảy ra. Thử lại sau.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  InputDecoration _field(
    String label,
    IconData icon, {
    Widget? suffix,
    String? hint,
  }) => InputDecoration(
    filled: true,
    fillColor: context.vd.accentSoft,
    labelText: label,
    hintText: hint,
    labelStyle: TextStyle(color: context.vd.accent),
    prefixIcon: Icon(icon, color: context.vd.accent),
    suffixIcon: suffix,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return Scaffold(
      backgroundColor: vd.surface,
      appBar: AppBar(title: const Text('Quên mật khẩu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              kForgotPasswordAsksBirthDate
                  ? 'Nhập mã số sinh viên và ngày sinh của bạn. Nếu đúng với hồ sơ của trường, mật khẩu sẽ được đặt lại thành mã số sinh viên; khi đăng nhập lại, bạn sẽ đặt mật khẩu mới.'
                  : 'Nhập mã số sinh viên của bạn. Mật khẩu sẽ được đặt lại thành mã số sinh viên; khi đăng nhập lại, bạn sẽ đặt mật khẩu mới.',
              style: TextStyle(color: vd.inkMuted, height: 1.4),
            ),
            const SizedBox(height: 20),
            TextField(
              key: const Key('forgot-mssv'),
              controller: _mssvCtrl,
              enabled: !_sending,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: kForgotPasswordAsksBirthDate
                  ? TextInputAction.next
                  : TextInputAction.done,
              decoration: _field('Mã số sinh viên (MSSV)', Icons.person),
            ),
            if (kForgotPasswordAsksBirthDate) ...[
              const SizedBox(height: 16),
              TextField(
                key: const Key('forgot-dob'),
                controller: _dobCtrl,
                enabled: !_sending,
                keyboardType: TextInputType.datetime,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
                  LengthLimitingTextInputFormatter(10),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: _field(
                  'Ngày sinh (ngày/tháng/năm)',
                  Icons.cake_outlined,
                  hint: 'VD: 09/03/2004',
                  suffix: IconButton(
                    tooltip: 'Chọn trên lịch',
                    icon: Icon(Icons.calendar_month, color: vd.accent),
                    onPressed: _sending ? null : _pickDate,
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                key: const Key('forgot-error'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: vd.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, style: TextStyle(color: vd.danger)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: FilledButton(
                key: const Key('forgot-submit'),
                onPressed: _sending ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: vd.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _sending
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: vd.onPrimary,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Đặt lại mật khẩu',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: vd.onPrimary,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
