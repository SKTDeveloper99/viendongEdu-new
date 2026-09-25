import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'app_session.dart';

// Background message handler — phải là top-level function
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Firebase đã tự hiển thị notification khi app ở background/terminated
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;
  Future<void> Function(String token)? _emsStudentRegister;
  Future<void> Function(String token)? _emsStudentRevoke;
  Future<void> Function(String token)? _emsTeacherRegister;
  Future<void> Function(String token)? _emsTeacherRevoke;

  // Danh tính đã đăng ký gần nhất — dùng để đăng ký lại khi FCM xoay token
  String? _lastHocVienId;
  String? _lastMssv;
  String? _lastHoTen;
  String? _lastNgaysinh;
  String? _lastUserid;

  final Completer<void> _initialMessageReady = Completer<void>();
  final Completer<void> _permissionReady = Completer<void>();

  /// Splash chờ cái này trước khi hỏi consumePendingInitialMessage()
  Future<void> get initialMessageReady => _initialMessageReady.future;

  Future<void> init() async {
    // Đọc initial message TRƯỚC tiên và báo cho splash biết ngay,
    // để splash không phải chờ requestPermission (người dùng có thể để yên hộp thoại)
    try {
      _pendingInitialMessage = await _fcm.getInitialMessage();
    } catch (e) {
      debugPrint('[FCM] getInitialMessage error: $e');
    }
    if (!_initialMessageReady.isCompleted) _initialMessageReady.complete();

    // Xin permission — trên iOS bước này hiện hộp thoại, phải await.
    // (Sửa của tdat535 11/09, lấy lại sạch từ bản có xung đột trên upstream.)
    try {
      await _fcm.requestPermission(alert: true, badge: true, sound: true);
    } finally {
      // Dù người dùng chọn "Cho phép" hay "Từ chối", vẫn báo done
      // để registerToken không bị chờ mãi mãi.
      if (!_permissionReady.isCompleted) _permissionReady.complete();
    }

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
        _showInAppBanner(title, body, _routeFor(message));
      }
    });

    // FCM xoay token (cài lại app, khôi phục iCloud, xoay định kỳ) →
    // đăng ký lại ngay, nếu không thì server giữ token cũ và notification chết im lặng
    _fcm.onTokenRefresh.listen((token) {
      debugPrint('[FCM] token refreshed');
      final id = _lastHocVienId;
      if (id == null) return;
      _postToken(
        id,
        token,
        mssv: _lastMssv,
        hoTen: _lastHoTen,
        ngaysinh: _lastNgaysinh,
        userid: _lastUserid,
      );
    });

    // Người dùng bấm vào notification khi app đang ở background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  RemoteMessage? _pendingInitialMessage;

  /// Splash gọi sau khi đã vào home — trả đúng màn hình mà push yêu cầu.
  String? consumePendingInitialMessageRoute() {
    final route = _pendingInitialMessage == null
        ? null
        : _routeFor(_pendingInitialMessage!);
    _pendingInitialMessage = null;
    return route;
  }

  /// Mặc định khi server không gắn `data['route']`: giảng viên có danh sách
  /// '/notifications' (CRM `/teacher/notifications`); học viên KHÔNG có màn
  /// tương đương nữa từ khi gỡ backend Vercel “noti-backend-eight” (bot A5,
  /// 2026-09-25) — điều hướng thẳng vào Bảng tin, nơi CRM thật sự có dữ liệu.
  String _routeFor(RemoteMessage message) {
    if (message.data['route'] == '/student/board') return '/student_board';
    return AppSession.instance.isGiangVien ? '/notifications' : '/student_board';
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] notification tapped: ${message.notification?.title}');
    final nav = _globalNavigatorKey?.currentState;
    if (nav == null) return;
    nav.pushNamed(_routeFor(message));
  }

  void _showInAppBanner(String title, String body, String route) {
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
          _globalNavigatorKey?.currentState?.pushNamed(route);
        },
      ),
    );

    overlay.insert(entry);

    // Tự đóng sau 4 giây
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  /// Lấy FCM token của thiết bị.
  /// Trên iOS phải đợi APNs cấp token trước, nếu không getToken() sẽ ném lỗi
  /// ở lần chạy đầu tiên sau khi cài app.
  Future<String?> getToken() async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        final apns = await _waitForApnsToken();
        if (apns == null) {
          debugPrint('[FCM] APNs token chưa sẵn sàng');
          return null;
        }
      }
      final token = await _fcm.getToken().timeout(const Duration(seconds: 10));
      if (kDebugMode && token != null) {
        debugPrint('[FCM] device token ready');
      }
      return token;
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
      return null;
    }
  }

  /// Hỏi APNs token nhiều lần — ngay sau khi cài app, iOS cần vài giây
  /// để đăng ký với APNs xong.
  Future<String?> _waitForApnsToken() async {
    for (var i = 0; i < 10; i++) {
      final apns = await _fcm.getAPNSToken();
      if (apns != null) return apns;
      await Future.delayed(const Duration(seconds: 1));
    }
    return null;
  }

  /// Lưu token lên server sau khi login
  Future<void> registerToken(
    String hocVienId, {
    String? mssv,
    String? hoTen,
    String? ngaysinh,
    String? userid,
  }) async {
    // Nhớ danh tính trước, để onTokenRefresh còn đăng ký lại được
    _lastHocVienId = hocVienId;
    _lastMssv = mssv;
    _lastHoTen = hoTen;
    _lastNgaysinh = ngaysinh;
    _lastUserid = userid;

    // Trên iOS: phải đợi requestPermission hoàn tất trước khi lấy APNs token.
    // Nếu init() vẫn đang chờ người dùng bấm hộp thoại, getToken() sẽ trả null.
    // Timeout 30s phòng trường hợp init() gặp lỗi bất ngờ.
    await _permissionReady.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );

    final token = await getToken();
    if (token == null) {
      // Không bỏ cuộc: onTokenRefresh sẽ bắn khi FCM cấp được token
      debugPrint('[FCM] Token chưa có, chờ onTokenRefresh');
      return;
    }
    await _postToken(
      hocVienId,
      token,
      mssv: mssv,
      hoTen: hoTen,
      ngaysinh: ngaysinh,
      userid: userid,
    );
  }

  /// Đăng ký token FCM lên EMS — học viên qua `/v1/student/board/devices`
  /// ([_emsStudentRegister]/[AppSession.registerStudentDeviceToken]), giảng
  /// viên qua `/teacher/notifications/devices`
  /// ([_emsTeacherRegister]/[AppSession.registerTeacherDeviceToken]). Cả hai
  /// gọi được lúc đăng nhập LẪN lúc khôi phục phiên/xoay token (khác với
  /// trước 2026-09-25: giảng viên chỉ đăng ký được lúc đăng nhập, qua
  /// `POST /auth/teacher/login {fcm_token, platform}` — route thiết bị riêng
  /// ở trên mới bù được khoảng trống đó, xem báo cáo gỡ Vercel, bot A5).
  Future<void> _postToken(
    String hocVienId,
    String token, {
    String? mssv,
    String? hoTen,
    String? ngaysinh,
    String? userid,
  }) async {
    if (hocVienId.startsWith('hv_')) {
      try {
        await _emsStudentRegister?.call(token);
      } catch (e) {
        debugPrint('[FCM] EMS register token error: $e');
      }
    } else if (hocVienId.startsWith('gv_')) {
      try {
        await _emsTeacherRegister?.call(token);
      } catch (e) {
        debugPrint('[FCM] EMS register token error: $e');
      }
    }
  }

  /// Xóa token khỏi EMS khi logout — cả học viên lẫn giảng viên đều có kênh
  /// CRM riêng (xem [_postToken]).
  Future<void> unregisterToken(String hocVienId) async {
    _lastHocVienId = null;
    _lastMssv = null;
    _lastHoTen = null;
    _lastNgaysinh = null;
    _lastUserid = null;
    final token = await getToken();
    if (token == null) return;
    if (hocVienId.startsWith('hv_')) {
      try {
        await _emsStudentRevoke?.call(token);
      } catch (_) {}
    } else if (hocVienId.startsWith('gv_')) {
      try {
        await _emsTeacherRevoke?.call(token);
      } catch (_) {}
    }
  }

  void configureEmsStudentDevice({
    required Future<void> Function(String token) register,
    required Future<void> Function(String token) revoke,
  }) {
    _emsStudentRegister = register;
    _emsStudentRevoke = revoke;
  }

  void configureEmsTeacherDevice({
    required Future<void> Function(String token) register,
    required Future<void> Function(String token) revoke,
  }) {
    _emsTeacherRegister = register;
    _emsTeacherRevoke = revoke;
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
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
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
                  border: Border.all(color: const Color(0xFFFFCC80), width: 1),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                      child: const Icon(
                        Icons.notifications_active,
                        color: Colors.white,
                        size: 22,
                      ),
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
                      child: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 18,
                      ),
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
