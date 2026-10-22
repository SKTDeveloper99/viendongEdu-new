import 'package:flutter/material.dart';

import '../../../services/ems_api_service.dart';
import '../attendance_format.dart';
import '../../../theme/vd_tokens.dart';

const punchIntro =
    'Những sinh viên này đã quẹt thẻ vào trường hôm nay. '
    'Thầy/cô vẫn có quyền ghi VẮNG — chỉ cần cho biết vì sao, '
    'và lý do sẽ được lưu lại.';

const otherIntro =
    'Thầy/cô chọn "Khác" cho những sinh viên này. Ghi rõ lý do '
    '(đi muộn, có phép, ốm…) — Phòng Đào tạo sẽ xem trước khi chuyển IMS.';

/// Bắt buộc nêu lý do cho từng học viên đã quẹt cổng mà bị ghi vắng.
/// Trả về map mssv -> lý do, hoặc null nếu thầy/cô bấm Huỷ.
Future<Map<String, String>?> showReasonsDialog(
  BuildContext context, {
  required List<EmsPunchedStudent> people,
  required Map<String, String> initial,
  required String Function(String mssv) nameOf,
  String intro = punchIntro,
}) {
  // Hộp thoại TỰ giữ controller và tự dispose trong dispose() của chính nó.
  //
  // Trước đây controller được tạo ở đây rồi dispose ngay sau await
  // showDialog. Nhưng showDialog trả về NGAY khi Navigator.pop chạy, trong
  // khi hộp thoại vẫn đang chạy hoạt ảnh đóng và các TextField vẫn còn sống
  // và vẫn đang dùng controller đó -> Flutter ném '_dependents.isEmpty'
  // (màn hình đỏ) đúng vào lúc thầy/cô bấm "Lưu kèm lý do".
  return showDialog<Map<String, String>>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ReasonsDialog(
      people: people,
      initial: initial,
      nameOf: nameOf,
      intro: intro,
    ),
  );
}

/// Hỏi lý do cho từng học viên đã quẹt cổng mà bị ghi vắng.
///
/// Là StatefulWidget để controller sống và chết CÙNG hộp thoại — đó là lý do
/// duy nhất nó tồn tại tách khỏi màn hình cha.
class ReasonsDialog extends StatefulWidget {
  const ReasonsDialog({
    super.key,
    required this.people,
    required this.initial,
    required this.nameOf,
    this.intro = punchIntro,
  });

  final List<EmsPunchedStudent> people;
  final Map<String, String> initial;
  final String Function(String mssv) nameOf;
  final String intro;

  @override
  State<ReasonsDialog> createState() => _ReasonsDialogState();
}

class _ReasonsDialogState extends State<ReasonsDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final p in widget.people)
      p.mssv: TextEditingController(text: widget.initial[p.mssv] ?? ''),
  };

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _complete =>
      _controllers.values.every((c) => c.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cần nêu lý do'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.intro, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            for (final p in widget.people) ...[
              Text(
                widget.nameOf(p.mssv),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                p.punchedAt == null
                    ? p.mssv
                    : '${p.mssv} • quẹt lúc ${schoolHhmm(p.punchedAt!)}',
                style: TextStyle(fontSize: 11, color: context.vd.inkMuted),
              ),
              TextField(
                controller: _controllers[p.mssv],
                // Nút "Lưu" bật/tắt theo ô trống, thay vì im lặng không ăn.
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Ví dụ: quẹt cổng nhưng không vào lớp',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _complete
              ? () => Navigator.pop(context, {
                  for (final e in _controllers.entries)
                    e.key: e.value.text.trim(),
                })
              : null,
          child: const Text('Lưu kèm lý do'),
        ),
      ],
    );
  }
}
