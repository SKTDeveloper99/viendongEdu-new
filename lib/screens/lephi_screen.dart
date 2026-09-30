import 'package:flutter/material.dart';
import '../models/crm_money_fees.dart';
import '../services/crm_money_api.dart';
import '../services/crm_session_guard.dart';
import '../theme/vd_tokens.dart';

String _fmtAmount(int? amount) {
  if (amount == null) return 'chưa có luật';
  final s = amount.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
    buf.write(s[i]);
  }
  return '${buf.toString()} đ';
}

String _fmtDate(DateTime? d) => d == null
    ? '–'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

// ── Screen — thay ApiService.getLePhi (IMS hocvien/lephi) bằng
// CrmMoneyApi.getFees (GET /api/student/me/fees). ──────────────────────────
class LePhiScreen extends StatefulWidget {
  const LePhiScreen({super.key});

  @override
  State<LePhiScreen> createState() => _LePhiScreenState();
}

class _LePhiScreenState extends State<LePhiScreen> {
  CrmFeesResponse? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await CrmMoneyApi.getFees();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _data?.items ?? const <CrmFeeItem>[];
    final totals = _data?.totals;
    return Scaffold(
      backgroundColor: context.vd.bg,
      body: SafeArea(top: false, child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [context.vd.primary, context.vd.accent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.arrow_back_ios,
                      color: context.vd.onPrimary, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  'Lệ phí',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.vd.onPrimary,
                  ),
                ),
              ],
            ),
          ),

          // ── Content ──
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: context.vd.primary))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: context.vd.inkFaint),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: TextStyle(color: context.vd.inkFaint),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetch,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: context.vd.primary),
                              child: Text('Thử lại',
                                  style: TextStyle(color: context.vd.onPrimary)),
                            ),
                          ],
                        ),
                      )
                    : items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.receipt_long_outlined,
                                    size: 64, color: context.vd.inkFaint),
                                SizedBox(height: 12),
                                Text('Không có lệ phí',
                                    style: TextStyle(color: context.vd.inkFaint)),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _fetch,
                            color: context.vd.primary,
                            child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding:
                                const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            children: [
                              // Tổng — LUẬT TIỀN: hiện đúng số máy chủ trả,
                              // không cộng lệ phí + miễn giảm + hoàn phí lại
                              // với nhau (ba khoản khác luật nhau).
                              Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      context.vd.primary,
                                      context.vd.accent
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                        color: context.vd.shadow,
                                        blurRadius: 8,
                                        offset: Offset(0, 4)),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Lệ phí khác',
                                            style: TextStyle(
                                                color: context.vd.onPrimary.withValues(alpha: 0.7),
                                                fontSize: 13)),
                                        const SizedBox(height: 4),
                                        Text(
                                          _fmtAmount(totals?.lePhiKhac),
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: context.vd.onPrimary,
                                          ),
                                        ),
                                        if ((totals?.mienGiamKhenThuong ?? 0) != 0) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Miễn giảm/khen thưởng: ${_fmtAmount(totals?.mienGiamKhenThuong)}',
                                            style: TextStyle(
                                                color: context.vd.onPrimary.withValues(alpha: 0.7),
                                                fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: context.vd.surface
                                            .withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.receipt_long,
                                          color: context.vd.onPrimary, size: 24),
                                    ),
                                  ],
                                ),
                              ),

                              if (totals?.paidSideContaminated == true)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: context.vd.accentSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          color: context.vd.primary, size: 18),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Dữ liệu có phiếu phát sinh bất thường — số liệu cần rà soát.',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              ...items.map((t) => _LePhiCard(item: t)),
                            ],
                          ),
                        ),
          ),
        ],
      )),
    );
  }
}

// ── Card ────────────────────────────────────────────────
class _LePhiCard extends StatelessWidget {
  final CrmFeeItem item;
  const _LePhiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.vd.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: context.vd.shadow, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.vd.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long,
                color: context.vd.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.loaiPhieuThu ?? '–',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  // Không có hkten (tên học kỳ) từ endpoint này — hiện mã
                  // học kỳ nguyên văn (vd. "261") thay vì bịa một nhãn.
                  item.semesterCode ?? '–',
                  style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
                ),
                if ((item.ghiChu ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.ghiChu!,
                    style: TextStyle(fontSize: 11, color: context.vd.inkFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtAmount(item.soTien),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: context.vd.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _fmtDate(item.ngayNop),
                style: TextStyle(fontSize: 11, color: context.vd.inkFaint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
