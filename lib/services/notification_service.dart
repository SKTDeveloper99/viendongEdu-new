import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _notiBase = 'https://noti-backend-eight.vercel.app';

// Background message handler — phải là top-level function
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase đã tự hiển thị notification khi app ở background/terminated
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;

  Future<void> init() async {
    // Xin permission
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Đăng ký background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Foreground: hiển thị notification khi app đang mở
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: true,
    );

    // Lắng nghe foreground message → hiện popup đẹp
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] foreground message: ${message.notification?.title}');
      final title = message.notification?.title ?? '';
      final body = message.notification?.body ?? '';
      if (title.isNotEmpty || body.isNotEmpty) {
        _showInAppBanner(title, body);
      }
    });
  }

  void _showInAppBanner(String title, String body) {
    final overlay = _globalNavigatorKey?.currentState?.overlay;
    if (overlay == null) return;

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _NotiiBanner(
        title: title,
        body: body,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
        onTap: () {
          if (entry.mounted) entry.remove();
          _globalNavigatorKey?.currentState?.pushNamed('/notifications');
        },
      ),
    );

    overlay.insert(entry);

    // Tự đóng sau 4 giây
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  /// Lấy FCM token của thiết bị
  Future<String?> getToken() async {
    try {
      // Thêm timeout 5s để tránh iOS bị treo (hang) khi chưa có APNs/Push Notifications entitlement
      return await _fcm.getToken().timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  /// Lưu token lên server sau khi login
  Future<void> registerToken(String hocVienId,
      {String? mssv, String? hoTen, String? ngaysinh, String? userid}) async {
    final token = await getToken();
    if (token == null) {
      debugPrint('[FCM] Token is null, skipping registration');
      return;
    }
    try {
      final res = await http
          .post(
            Uri.parse('$_notiBase/api/token/register-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'hocVienId': hocVienId,
              'token': token,
              if (mssv != null) 'mssv': mssv,
              if (hoTen != null) 'hoTen': hoTen,
              if (ngaysinh != null) 'ngaysinh': ngaysinh,
              if (userid != null) 'userid': userid,
            }),
          )
          .timeout(const Duration(seconds: 10));
      debugPrint('[FCM] Register token: ${res.statusCode} ${res.body}');
    } catch (e) {
      debugPrint('[FCM] Register token error: $e');
    }
  }

  /// Xóa token khỏi server khi logout
  Future<void> unregisterToken(String hocVienId) async {
    final token = await getToken();
    if (token == null) return;
    try {
      await http
          .delete(
            Uri.parse('$_notiBase/api/token/register-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'hocVienId': hocVienId, 'token': token}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {}
  }
}

// navigatorKey được set từ main.dart
GlobalKey<NavigatorState>? _globalNavigatorKey;

void setNotificationNavigatorKey(GlobalKey<NavigatorState> key) {
  _globalNavigatorKey = key;
}

// ── Custom in-app banner ──────────────────────────────────────────────────────

class _NotiiBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _NotiiBanner({
    required this.title,
    required this.body,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_NotiiBanner> createState() => _NotiiBannerState();
}

class _NotiiBannerState extends State<_NotiiBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFFFFCC80),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.title.isNotEmpty)
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (widget.body.isNotEmpty) ...[
                            if (widget.title.isNotEmpty)
                              const SizedBox(height: 3),
                            Text(
                              widget.body,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _dismiss,
                      child: const Icon(Icons.close,
                          color: Colors.grey, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
