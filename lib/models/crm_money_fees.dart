/// Lệ phí (fees) — `GET /api/student/me/fees`.
///
/// Mọi phiếu thu KHÔNG PHẢI học phí (loại 162/166/167/171/172/176/165/…),
/// nhóm theo luật thu ở CLAUDE.md. LUẬT TIỀN: hiển thị nguyên văn, không
/// cộng/trừ/gộp trên app.
library;

int? _numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return int.tryParse(s) ?? double.tryParse(s)?.toInt();
}

String? _strOrNull(dynamic v) {
  final s = v?.toString();
  if (s == null || s.isEmpty) return null;
  return s;
}

/// `totals` — tổng theo từng nhóm luật thu.
class CrmFeeTotals {
  final int? lePhiKhac;
  final int? mienGiamKhenThuong;
  final int? hoanPhi;
  final int? phatSinhCharges;

  /// `true` = có phiếu loại phát-sinh-thu (161/199) lọt vào — nghĩa là dữ
  /// liệu bị nhiễm, PHẢI hiện cảnh báo, không được lặng lẽ hiện số.
  final bool paidSideContaminated;

  const CrmFeeTotals({
    this.lePhiKhac,
    this.mienGiamKhenThuong,
    this.hoanPhi,
    this.phatSinhCharges,
    this.paidSideContaminated = false,
  });

  factory CrmFeeTotals.fromJson(Map<String, dynamic>? j) => CrmFeeTotals(
        lePhiKhac: _numOrNull(j?['le_phi_khac']),
        mienGiamKhenThuong: _numOrNull(j?['mien_giam_khen_thuong']),
        hoanPhi: _numOrNull(j?['hoan_phi']),
        phatSinhCharges: _numOrNull(j?['phat_sinh_charges']),
        paidSideContaminated: j?['paid_side_contaminated'] == true,
      );
}

/// Một dòng trong `by_type[]` — tổng theo loại phiếu thu.
class CrmFeeTypeBucket {
  final int? typeId;
  final String? typeName;
  final String? bucket;
  final int? tong;
  final int? soLan;

  const CrmFeeTypeBucket({
    this.typeId,
    this.typeName,
    this.bucket,
    this.tong,
    this.soLan,
  });

  factory CrmFeeTypeBucket.fromJson(Map<String, dynamic> j) => CrmFeeTypeBucket(
        typeId: _numOrNull(j['type_id']),
        typeName: _strOrNull(j['type_name']),
        bucket: _strOrNull(j['bucket']),
        tong: _numOrNull(j['tong']),
        soLan: _numOrNull(j['so_lan']),
      );
}

/// Một phiếu thu trong `items[]` — thay cho `LePhiItem` cũ (IMS).
class CrmFeeItem {
  final String? phieuThuId;
  final String? semesterCode;
  final int? soTien;
  final DateTime? ngayNop;
  final String? soBienLai;
  final String? ghiChu;
  final String? khoa;
  final int? loaiPhieuThuId;
  final String? loaiPhieuThu;
  final String? ledger;

  const CrmFeeItem({
    this.phieuThuId,
    this.semesterCode,
    this.soTien,
    this.ngayNop,
    this.soBienLai,
    this.ghiChu,
    this.khoa,
    this.loaiPhieuThuId,
    this.loaiPhieuThu,
    this.ledger,
  });

  factory CrmFeeItem.fromJson(Map<String, dynamic> j) => CrmFeeItem(
        phieuThuId: _strOrNull(j['phieu_thu_id']),
        semesterCode: _strOrNull(j['semester_code']),
        soTien: _numOrNull(j['so_tien']),
        ngayNop: DateTime.tryParse(j['ngay_nop']?.toString() ?? '')?.toLocal(),
        soBienLai: _strOrNull(j['so_bien_lai']),
        ghiChu: _strOrNull(j['ghi_chu']),
        khoa: _strOrNull(j['khoa']),
        loaiPhieuThuId: _numOrNull(j['loai_phieu_thu_id']),
        loaiPhieuThu: _strOrNull(j['loai_phieu_thu']),
        ledger: _strOrNull(j['ledger']),
      );
}

/// `GET /api/student/me/fees` → `{mssv, totals, by_type, items}`.
class CrmFeesResponse {
  final String? mssv;
  final CrmFeeTotals totals;
  final List<CrmFeeTypeBucket> byType;
  final List<CrmFeeItem> items;

  const CrmFeesResponse({
    this.mssv,
    required this.totals,
    this.byType = const [],
    this.items = const [],
  });

  factory CrmFeesResponse.fromJson(Map<String, dynamic> j) => CrmFeesResponse(
        mssv: _strOrNull(j['mssv']),
        totals: CrmFeeTotals.fromJson(j['totals'] as Map<String, dynamic>?),
        byType: (j['by_type'] is List)
            ? (j['by_type'] as List)
                .whereType<Map<String, dynamic>>()
                .map(CrmFeeTypeBucket.fromJson)
                .toList()
            : const [],
        items: (j['items'] is List)
            ? (j['items'] as List)
                .whereType<Map<String, dynamic>>()
                .map(CrmFeeItem.fromJson)
                .toList()
            : const [],
      );
}
