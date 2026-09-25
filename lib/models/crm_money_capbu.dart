/// Cấp bù (state tuition compensation) — `GET /api/student/me/capbu`.
///
/// Mirror THẲNG từ `ims_snapshot` (IMS-only, không có luật CRM) — số liệu
/// nguyên văn, KHÔNG được tính lại hay suy luận trên app. `null` nghĩa là
/// một cột chuỗi-tiền IMS để trống, không phải 0.
library;

num? _numOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return num.tryParse(s);
}

String? _strOrNull(dynamic v) {
  final s = v?.toString();
  if (s == null || s.isEmpty) return null;
  return s;
}

/// Một hóa đơn cấp bù trong `items[]`.
class CrmCapBuItem {
  final String? id;
  final String? ma;
  final String? ten;
  final String? kyHieu;
  final DateTime? ngayCap;
  final num? donGia;
  final num? thanhTien;
  final num? vat;
  final num? total;
  final String? ghiChu;
  final String? hocKyId;
  final String? hocKyTen;

  const CrmCapBuItem({
    this.id,
    this.ma,
    this.ten,
    this.kyHieu,
    this.ngayCap,
    this.donGia,
    this.thanhTien,
    this.vat,
    this.total,
    this.ghiChu,
    this.hocKyId,
    this.hocKyTen,
  });

  factory CrmCapBuItem.fromJson(Map<String, dynamic> j) => CrmCapBuItem(
        id: _strOrNull(j['id']),
        ma: _strOrNull(j['ma']),
        ten: _strOrNull(j['ten']),
        kyHieu: _strOrNull(j['ky_hieu']),
        ngayCap: DateTime.tryParse(j['ngay_cap']?.toString() ?? '')?.toLocal(),
        donGia: _numOrNull(j['don_gia']),
        thanhTien: _numOrNull(j['thanh_tien']),
        vat: _numOrNull(j['vat']),
        total: _numOrNull(j['total']),
        ghiChu: _strOrNull(j['ghi_chu']),
        hocKyId: _strOrNull(j['hocky_id']),
        hocKyTen: _strOrNull(j['hocky_ten']),
      );
}

/// `GET /api/student/me/capbu` → `{mssv, count, items}`.
class CrmCapBuResponse {
  final String? mssv;
  final int count;
  final List<CrmCapBuItem> items;

  const CrmCapBuResponse({this.mssv, this.count = 0, this.items = const []});

  factory CrmCapBuResponse.fromJson(Map<String, dynamic> j) => CrmCapBuResponse(
        mssv: _strOrNull(j['mssv']),
        count: (j['count'] as num?)?.toInt() ?? 0,
        items: (j['items'] is List)
            ? (j['items'] as List)
                .whereType<Map<String, dynamic>>()
                .map(CrmCapBuItem.fromJson)
                .toList()
            : const [],
      );
}
