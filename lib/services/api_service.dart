import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_session.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static const _base = 'http://ims-api.viendong.edu.vn/api/v1';

  // ── In-memory cache ──────────────────────────────────
  static List<dynamic>? _hocKyCache;

  static void clearCache() {
    _hocKyCache = null;
  }

  static Map<String, String> get _headers {
    final h = <String, String>{'Content-Type': 'application/json'};
    final token = AppSession.instance.token;
    if (token != null && token.isNotEmpty) h['token'] = token;
    return h;
  }

  // ── Đăng nhập ───────────────────────────────────────
  /// Trả về toàn bộ body response khi success = true
  static Future<Map<String, dynamic>> login(String userid, String pass) async {
    final uri = Uri.parse('$_base/login');
    final http.Response res;

    try {
      res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'userid': userid, 'pass': pass}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Lỗi kết nối iOS: ${e.toString()}');
    }

    final body = _decode(res);

    if (body['success'] != true) {
      throw ApiException(
          body['message']?.toString() ?? 'Tên đăng nhập hoặc mật khẩu sai.');
    }

    return body;
  }

  // ── Lịch thi GV theo khoảng ngày ────────────────────
  static Future<List<dynamic>> getGvLichThi(String tungay, String denngay) async {
    final uri = Uri.parse('$_base/giangvien/lichthi').replace(
      queryParameters: {'tungay': tungay, 'denngay': denngay},
    );
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Danh sách buổi học điểm danh theo lớp ───────────
  static Future<List<dynamic>> getGvDanhSachBuoiHoc(int lopid) async {
    final uri = Uri.parse('$_base/giangvien/diemdanh/lopmonhoc/danhsachbuoihoc')
        .replace(queryParameters: {'lopid': lopid.toString()});
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Tổng hợp điểm danh theo lớp ─────────────────────
  static Future<List<dynamic>> getGvDanhSachTongHop(int lopid) async {
    final uri = Uri.parse('$_base/giangvien/diemdanh/danhsachtonghop')
        .replace(queryParameters: {'lopid': lopid.toString()});
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Danh sách học viên theo lớp môn học ─────────────
  static Future<List<dynamic>> getGvDanhSachHocVien(int lopmonhocid) async {
    final uri = Uri.parse('$_base/giangvien/danhsachhocvien').replace(
      queryParameters: {'lopmonhocid': lopmonhocid.toString()},
    );
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Danh sách lớp GV theo học kỳ ───────────────────
  static Future<List<dynamic>> getGvDanhSachLop(int hockyid) async {
    final uri = Uri.parse('$_base/giangvien/danhsachlop').replace(
      queryParameters: {'hockyid': hockyid.toString()},
    );
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── TKB GV theo học kỳ ──────────────────────────────
  static Future<List<dynamic>> getGvTkbTheoHocKy(int hockyid) async {
    final uri = Uri.parse('$_base/giangvien/tkbtheohocky').replace(
      queryParameters: {'hockyid': hockyid.toString()},
    );
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Lịch học GV theo ngày ───────────────────────────
  static Future<List<dynamic>> getGvScheduleByDate(String date) async {
    final uri = Uri.parse('$_base/giangvien/tkbtheongay').replace(
      queryParameters: {'ngay': date},
    );
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Lịch học theo ngày ──────────────────────────────
  /// [date] format: "yyyy-MM-dd", nếu null thì lấy hôm nay
  static Future<List<dynamic>> getScheduleByDate(String date) async {
    final uri = Uri.parse('$_base/hocvien/tkbtheongay').replace(
      queryParameters: {'ngay': date},
    );
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Lịch học hôm nay ────────────────────────────────
  static Future<List<dynamic>> getTodaySchedule() async {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return getScheduleByDate(date);
  }

  // ── Lịch thi ────────────────────────────────────────
  static Future<List<dynamic>> getExams(String ngayBD) async {
    final uri = Uri.parse('$_base/hocvien/lichthi').replace(
      queryParameters: {'ngayBD': ngayBD},
    );
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Danh sách học kỳ (có cache) ─────────────────────
  static Future<List<dynamic>> getHocKy() async {
    if (_hocKyCache != null) return _hocKyCache!;
    final uri = Uri.parse('$_base/hocky');
    final http.Response res;
    try {
      res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Không thể kết nối đến máy chủ.');
    }
    if (res.statusCode == 401) {
      throw ApiException('Phiên đăng nhập hết hạn.', statusCode: 401);
    }
    try {
      _hocKyCache = jsonDecode(res.body) as List<dynamic>;
      return _hocKyCache!;
    } catch (_) {
      throw ApiException('Phản hồi không hợp lệ từ máy chủ.');
    }
  }

  // ── Buổi học / điểm danh theo lớp ───────────────────
  static Future<List<dynamic>> getBuoiHoc(int lmhid) async {
    final uri = Uri.parse('$_base/hocvien/lopmonhoc/buoihoc').replace(
      queryParameters: {'lmhid': lmhid.toString()},
    );
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Lớp môn học theo học kỳ ─────────────────────────
  static Future<List<dynamic>> getLopMonHoc(int hockyid) async {
    final uri = Uri.parse('$_base/hocvien/lopmonhoc').replace(
      queryParameters: {'hockyid': hockyid.toString()},
    );
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Cập nhật thông tin ──────────────────────────────
  static Future<void> updateUserInfo(
      {required String email,
      required String sdt,
      required String cmnd}) async {
    final uri = Uri.parse('$_base/user/info/update');
    final http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({'email': email, 'sdt': sdt, 'cmnd': cmnd}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Không thể kết nối đến máy chủ.');
    }
    final body = _decode(res);
    if (body['success'] != true) {
      throw ApiException(
          body['message']?.toString() ?? 'Cập nhật thất bại.');
    }
  }

  // ── Lưu điểm danh ───────────────────────────────────
  static Future<void> postDiemDanhLuu({
    required Map<String, dynamic> tkb,
    required List<Map<String, dynamic>> hocviens,
  }) async {
    final uri = Uri.parse('$_base/giangvien/diemdanh/luu');
    final http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({'tkb': tkb, 'hocviens': hocviens}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Không thể kết nối đến máy chủ.');
    }
    final body = _decode(res);
    if (body['success'] != true) {
      throw ApiException(body['message']?.toString() ?? 'Lưu thất bại.');
    }
  }

  // ── Điểm danh danh sách ─────────────────────────────
  static Future<List<dynamic>> postDiemDanhDanhSach({
    required String tkbid,
    required String lopid,
    required String phongid,
    required String ngay,
    required String thoigianbd,
    required String thoigiankt,
  }) async {
    final uri = Uri.parse('$_base/giangvien/diemdanh/danhsach');
    final http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'tkbid': tkbid,
              'lopid': lopid,
              'phongid': phongid,
              'ngay': ngay,
              'thoigianbd': thoigianbd,
              'thoigiankt': thoigiankt,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Không thể kết nối đến máy chủ.');
    }
    final body = _decode(res);
    return body['data'] as List<dynamic>? ?? [];
  }

  // ── Đổi mật khẩu ────────────────────────────────────
  static Future<void> changePassword({
    required String oldpass,
    required String newpass,
  }) async {
    final uri = Uri.parse('$_base/user/changepass');
    final http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({'oldpass': oldpass, 'newpass': newpass}),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Không thể kết nối đến máy chủ.');
    }
    final body = _decode(res);
    if (body['success'] != true) {
      throw ApiException(
          body['message']?.toString() ?? 'Đổi mật khẩu thất bại.');
    }
  }

  // ── Cấp bù ──────────────────────────────────────────
  static Future<List<dynamic>> getCapBu() async {
    final uri = Uri.parse('$_base/hocvien/capbu');
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Lệ phí ──────────────────────────────────────────
  static Future<List<dynamic>> getLePhi() async {
    final uri = Uri.parse('$_base/hocvien/lephi');
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Học phí ─────────────────────────────────────────
  static Future<List<dynamic>> getTuition() async {
    final uri = Uri.parse('$_base/hocvien/hocphi');
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Thống kê CTĐT ───────────────────────────────────
  static Future<Map<String, dynamic>> getThongKeCTDT() async {
    final uri = Uri.parse('$_base/hocvien/thongkectdt');
    final res = await _get(uri);
    final data = res['data'] as List<dynamic>?;
    return data != null && data.isNotEmpty
        ? data.first as Map<String, dynamic>
        : {};
  }

  // ── Bảng điểm tổng kết ──────────────────────────────
  static Future<List<dynamic>> getBangDiem() async {
    final uri = Uri.parse('$_base/hocvien/bangdiemtongket');
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Bảng điểm theo học kỳ ───────────────────────────
  static Future<List<dynamic>> getBangDiemHocKy() async {
    final uri = Uri.parse('$_base/hocvien/bangdiemhocky');
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Thông tin user ───────────────────────────────────
  static Future<Map<String, dynamic>> getUserInfo() async {
    final uri = Uri.parse('$_base/user/info');
    final http.Response res;
    try {
      res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Không thể kết nối đến máy chủ.');
    }
    return _decode(res);
  }

  // ── Môn học chưa đạt ────────────────────────────────
  static Future<List<dynamic>> getMonHocChuaDat() async {
    final uri = Uri.parse('$_base/hocvien/monhocchuadat');
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  // ── Đăng ký môn ─────────────────────────────────────
  static Future<List<dynamic>> getKetQuaDangKy(int hockyid) async {
    final uri = Uri.parse('$_base/hocvien/ketquadk').replace(
      queryParameters: {'hockyid': hockyid.toString()},
    );
    final http.Response res;
    try {
      res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Không thể kết nối đến máy chủ.');
    }
    if (res.statusCode == 401) {
      throw ApiException('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
          statusCode: 401);
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['data'] is List) {
        return decoded['data'] as List<dynamic>;
      }
      return [];
    } catch (_) {
      throw ApiException('Phản hồi không hợp lệ từ máy chủ.');
    }
  }

  static Future<List<dynamic>> getDotDangKy(int hockyid) async {
    final uri = Uri.parse('$_base/hocvien/dotdangky').replace(
      queryParameters: {'hockyid': hockyid.toString()},
    );
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  static Future<List<dynamic>> getMonHocDuKien(int hockyid) async {
    final uri = Uri.parse('$_base/hocvien/monhocdukien').replace(
      queryParameters: {'hockyid': hockyid.toString()},
    );
    final res = await _get(uri);
    return res['data'] as List<dynamic>? ?? [];
  }

  static Future<void> postDangKyMon({
    required String hocvienid,
    required String dotdkid,
    required String monhocid,
    required String hockyid,
  }) async {
    final uri = Uri.parse('$_base/hocvien/dangky');
    final http.Response res;
    try {
      res = await http
          .post(
            uri,
            headers: _headers,
            body: jsonEncode({
              'hocvienid': hocvienid,
              'dotdkid': dotdkid,
              'monhocid': monhocid,
              'hockyid': hockyid,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Không thể kết nối đến máy chủ.');
    }
    final body = _decode(res);
    if (body['success'] != true) {
      throw ApiException(body['message']?.toString() ?? 'Đăng ký thất bại.');
    }
  }

  static Future<void> deleteDangKyMon({
    required String hocvienid,
    required String dotdkid,
    required String monhocid,
    required String hockyid,
  }) async {
    final uri = Uri.parse('$_base/hocvien/dangky');
    final http.Response res;
    try {
      res = await http
          .delete(
            uri,
            headers: _headers,
            body: jsonEncode({
              'hocvienid': hocvienid,
              'dotdkid': dotdkid,
              'monhocid': monhocid,
              'hockyid': hockyid,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Không thể kết nối đến máy chủ.');
    }
    final body = _decode(res);
    if (body['success'] != true) {
      throw ApiException(body['message']?.toString() ?? 'Hủy đăng ký thất bại.');
    }
  }

  // ── Send SMS (CD15) ──────────────────────────────────
  static Future<void> sendSMS({
    required Map<String, dynamic> subject,
    required List<Map<String, dynamic>> classData,
  }) async {
    final payload = jsonEncode({'subject': subject, 'classData': classData});
    final headers = {'Content-Type': 'application/json'};
    final urls = [
      'https://vido-ts-one.vercel.app/api/mobile/sendSMS',
      'https://tuyensinhcd-dh.viendong.edu.vn/api/mobile/sendSMS',
    ];

    for (final url in urls) {
      try {
        await http
            .post(Uri.parse(url), headers: headers, body: payload)
            .timeout(const Duration(seconds: 15));
        return; // thành công thì dừng
      } catch (_) {
        // thử url tiếp theo
      }
    }
    // cả 2 đều lỗi → bỏ qua, không ảnh hưởng điểm danh
  }

  // ── Internal helpers ─────────────────────────────────
  static Future<Map<String, dynamic>> _get(Uri uri) async {
    final http.Response res;
    try {
      res = await http
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw ApiException('Không thể kết nối đến máy chủ.');
    }
    return _decode(res);
  }

  static Map<String, dynamic> _decode(http.Response res) {
    if (res.statusCode == 401) {
      throw ApiException('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.',
          statusCode: 401);
    }
    if (res.statusCode >= 500) {
      throw ApiException('Lỗi máy chủ (${res.statusCode}).',
          statusCode: res.statusCode);
    }
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Phản hồi không hợp lệ từ máy chủ.');
    }
  }
}
