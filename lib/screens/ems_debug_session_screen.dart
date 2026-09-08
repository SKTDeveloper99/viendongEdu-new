// lib/screens/ems_debug_session_screen.dart
//
// Cửa vào cho buổi chạy thử — CHỈ CÓ TRONG BẢN DEBUG.
//
// Màn hình điểm danh EMS cần token EMS, mà token EMS bình thường chỉ có được
// sau khi đăng nhập IMS rồi đối chiếu. Để diễn thử trên máy giả lập với dữ
// liệu thật của buổi sáng, ta cần đặt thẳng token vào phiên.
//
// `kDebugMode` là rào chắn thật: `flutter build --release` biến nó thành hằng
// số false, cây widget bị cắt bỏ khi biên dịch, nên không có đường nào vào
// màn hình này trong bản phát hành. Route cũng chỉ được đăng ký khi debug.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/app_session.dart';

class EmsDebugSessionScreen extends StatefulWidget {
  const EmsDebugSessionScreen({super.key});

  @override
  State<EmsDebugSessionScreen> createState() => _EmsDebugSessionScreenState();
}

class _EmsDebugSessionScreenState extends State<EmsDebugSessionScreen> {
  final _token = TextEditingController();
  String _msg = '';

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final t = _token.text.trim();
    if (t.isEmpty) {
      setState(() => _msg = 'Chưa dán token.');
      return;
    }
    AppSession.instance.emsToken = t;
    AppSession.instance.emsDenied = false;
    await AppSession.instance.persist();
    if (!mounted) return;
    setState(() => _msg = 'Đã đặt token EMS cho phiên chạy thử.');
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const Scaffold(body: Center(child: Text('Không khả dụng.')));
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('Phiên chạy thử EMS'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chỉ dùng cho buổi diễn thử trên máy giả lập. Dán token EMS do '
              'máy chủ nội bộ cấp, rồi mở màn hình điểm danh.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Token EMS',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
              ),
              onPressed: _apply,
              child: const Text('Đặt token'),
            ),
            const SizedBox(height: 12),
            if (_msg.isNotEmpty)
              Text(_msg, style: const TextStyle(color: Color(0xFF2E7D32))),
            const Divider(height: 32),
            OutlinedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/ems_attendance_gv'),
              child: const Text('Mở màn hình GIÁO VIÊN'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, '/ems_attendance_hv'),
              child: const Text('Mở màn hình HỌC VIÊN'),
            ),
          ],
        ),
      ),
    );
  }
}
