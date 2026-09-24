/// Học phí (tuition) — dựng từ `GET /api/student/me/tuition` và
/// `GET /api/student/me/cong-no`.
///
/// LUẬT TIỀN (CLAUDE.md): hiển thị NGUYÊN VĂN số liệu máy chủ trả về. KHÔNG
/// cộng/trừ/tính lại trên điện thoại. Nếu máy chủ trả "chưa có luật" hoặc
/// null cho một khoản, hiển thị đúng như vậy — không được hiện 0.
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

/// Một dòng giao dịch (`payments[]`).
class CrmTuitionPayment {
  final String? phieuThuId;
  final int? soTien;
  final DateTime? ngayNop;
  final String? ghiChu;
  final String? semesterCode;
  final String? loaiPhieuThu;

  const CrmTuitionPayment({
    this.phieuThuId,
    this.soTien,
    this.ngayNop,
    this.ghiChu,
    this.semesterCode,
    this.loaiPhieuThu,
  });

  factory CrmTuitionPayment.fromJson(Map<String, dynamic> j) =>
      CrmTuitionPayment(
        phieuThuId: _strOrNull(j['phieu_thu_id']),
        soTien: _numOrNull(j['so_tien']),
        ngayNop: DateTime.tryParse(j['ngay_nop']?.toString() ?? '')?.toLocal(),
        ghiChu: _strOrNull(j['ghi_chu']),
        semesterCode: _strOrNull(j['semester_code']),
        loaiPhieuThu: _strOrNull(j['loai_phieu_thu']),
      );
}

/// Khoản thu khác đi kèm (miễn giảm, lệ phí khác, hoàn phí) — KHÔNG BAO GIỜ
/// cộng vào học phí. `summary.other_receipts`.
class CrmOtherReceipts {
  final int? mienGiamKhenThuong;
  final int? lePhiKhac;
  final int? hoanPhi;
  final int? total;

  const CrmOtherReceipts({
    this.mienGiamKhenThuong,
    this.lePhiKhac,
    this.hoanPhi,
    this.total,
  });

  factory CrmOtherReceipts.fromJson(Map<String, dynamic>? j) =>
      CrmOtherReceipts(
        mienGiamKhenThuong: _numOrNull(j?['mien_giam_khen_thuong']),
        lePhiKhac: _numOrNull(j?['le_phi_khac']),
        hoanPhi: _numOrNull(j?['hoan_phi']),
        total: _numOrNull(j?['total']),
      );
}

/// `summary` — tổng đã tính sẵn theo luật thu, KHÔNG cộng lại trên app.
class CrmTuitionSummary {
  final int? owedTotal;
  final int? paid;
  final int? balance;
  final String? paymentStatus;
  final CrmOtherReceipts otherReceipts;

  /// `false` khi máy chủ CHƯA CÓ LUẬT cho khoản này (vd. CD15 chưa có giá) —
  /// app phải hiện [moneyUnknownReason], không được suy ra 0.
  final bool moneyKnown;
  final String? moneyUnknownReason;

  const CrmTuitionSummary({
    this.owedTotal,
    this.paid,
    this.balance,
    this.paymentStatus,
    this.otherReceipts = const CrmOtherReceipts(),
    this.moneyKnown = true,
    this.moneyUnknownReason,
  });

  factory CrmTuitionSummary.fromJson(Map<String, dynamic>? j) =>
      CrmTuitionSummary(
        owedTotal: _numOrNull(j?['owedTotal']),
        paid: _numOrNull(j?['paid']),
        balance: _numOrNull(j?['balance']),
        paymentStatus: _strOrNull(j?['payment_status']),
        otherReceipts:
            CrmOtherReceipts.fromJson(j?['other_receipts'] as Map<String, dynamic>?),
        // Mặc định true: chỉ khi máy chủ NÓI RÕ money_known=false mới coi là
        // chưa có luật — tránh một field vắng bị hiểu nhầm thành "chưa biết".
        moneyKnown: j?['money_known'] != false,
        moneyUnknownReason: _strOrNull(j?['money_unknown_reason']),
      );
}

/// `GET /api/student/me/tuition` → `{mssv, summary, payments}`.
class CrmTuitionResponse {
  final String? mssv;
  final CrmTuitionSummary summary;
  final List<CrmTuitionPayment> payments;

  const CrmTuitionResponse({
    this.mssv,
    required this.summary,
    this.payments = const [],
  });

  factory CrmTuitionResponse.fromJson(Map<String, dynamic> j) =>
      CrmTuitionResponse(
        mssv: _strOrNull(j['mssv']),
        summary: CrmTuitionSummary.fromJson(j['summary'] as Map<String, dynamic>?),
        payments: (j['payments'] is List)
            ? (j['payments'] as List)
                .whereType<Map<String, dynamic>>()
                .map(CrmTuitionPayment.fromJson)
                .toList()
            : const [],
      );
}

/// `GET /api/student/me/cong-no` — sổ công nợ IMS đọc từ sổ cái sống
/// (`vw_hocvien_hocphi`), một nguồn RIÊNG với [CrmTuitionSummary] — CHỦ Ý
/// tách biệt (comment của router), không được gộp/trung bình hai bên.
/// `null` ở [phaiNop]/[daNop]/[congNo] nghĩa là CHƯA CÓ nghĩa vụ được ghi
/// nhận (xem [note]) — không phải 0.
class CrmCongNo {
  final String? mssv;
  final int? phaiNop;
  final int? daNop;
  final int? congNo;
  final bool computable;
  final bool hasMoneyRows;
  final String? note;

  const CrmCongNo({
    this.mssv,
    this.phaiNop,
    this.daNop,
    this.congNo,
    this.computable = true,
    this.hasMoneyRows = false,
    this.note,
  });

  factory CrmCongNo.fromJson(Map<String, dynamic> j) => CrmCongNo(
        mssv: _strOrNull(j['mssv']),
        phaiNop: _numOrNull(j['phai_nop']),
        daNop: _numOrNull(j['da_nop']),
        congNo: _numOrNull(j['cong_no']),
        computable: j['computable'] != false,
        hasMoneyRows: j['has_money_rows'] == true,
        note: _strOrNull(j['note']),
      );
}
