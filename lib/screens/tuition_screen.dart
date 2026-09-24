import 'package:flutter/material.dart';
import '../models/crm_money_tuition.dart';
import '../services/crm_money_api.dart';
import '../services/crm_session_guard.dart';

// ── Helpers ─────────────────────────────────────────────
// LUẬT TIỀN (CLAUDE.md): hiện NGUYÊN VĂN số máy chủ trả. null nghĩa là
// "chưa có luật"/không tính được — không bao giờ hiện 0.
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

// ── Screen ──────────────────────────────────────────────
// Thay ApiService.getTuition (IMS hocvien/hocphi) bằng CrmMoneyApi.getTuition
// (GET /api/student/me/tuition) + CrmMoneyApi.getCongNo (GET
// /api/student/me/cong-no). KHÔNG tự cộng/trừ soTien trên app nữa — đó
// chính là lỗi "type-blind" mà CRM đã sửa một lần (BUG 2, xem S4 doc); màn
// hình chỉ ĐỌC summary đã áp luật thu sẵn từ máy chủ.
class TuitionScreen extends StatefulWidget {
  const TuitionScreen({super.key});

  @override
  State<TuitionScreen> createState() => _TuitionScreenState();
}

class _TuitionScreenState extends State<TuitionScreen> {
  CrmTuitionResponse? _tuition;
  CrmCongNo? _congNo;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        CrmMoneyApi.getTuition(),
        CrmMoneyApi.getCongNo(),
      ]);
      if (!mounted) return;
      setState(() {
        _tuition = results[0] as CrmTuitionResponse;
        _congNo = results[1] as CrmCongNo;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (await CrmSessionGuard.handleIfExpired(context, e)) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = _tuition?.payments ?? const <CrmTuitionPayment>[];
    final summary = _tuition?.summary;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(top: false, child: Column(
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: const Row(
              children: [
                _BackButton(),
                SizedBox(width: 8),
                Text(
                  'Học phí',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFE65100)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetch,
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE65100)),
                              child: const Text('Thử lại',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFFE65100),
                        onRefresh: _fetch,
                        child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Summary (từ summary đã áp luật, không tự tính) ──
                  _SummarySection(summary: summary),
                  const SizedBox(height: 12),

                  if (_congNo != null) _CongNoCard(congNo: _congNo!),
                  const SizedBox(height: 20),

                  // ── Section label ──
                  const Text(
                    'Lịch sử giao dịch',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // ── Transaction list ──
                  if (payments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: Colors.grey),
                            SizedBox(height: 12),
                            Text('Không có giao dịch',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...payments.map((t) => _TransactionCard(item: t)),
                ],
              ),
            ),
          ),
        ),
        ],
      )),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
      );
}

// ── Summary Section ─────────────────────────────────────
class _SummarySection extends StatelessWidget {
  final CrmTuitionSummary? summary;

  const _SummarySection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final unknown = s == null || !s.moneyKnown;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tổng học phí phải đóng',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                _fmtAmount(s?.owedTotal),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (unknown) ...[
                const SizedBox(height: 6),
                Text(
                  s?.moneyUnknownReason ?? 'Chưa có luật tính học phí cho lớp này.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
              const SizedBox(height: 4),
              if (s?.paymentStatus != null)
                Text(
                  s!.paymentStatus!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── 2 stat cards — đọc thẳng từ summary, không tự cộng ──
        Row(
          children: [
            Expanded(
              child: _MiniCard(
                icon: Icons.check_circle_outline,
                label: 'Đã đóng',
                text: _fmtAmount(s?.paid),
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniCard(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Còn lại',
                text: _fmtAmount(s?.balance),
                color: const Color(0xFFF44336),
              ),
            ),
          ],
        ),

        if (s != null && (s.otherReceipts.total ?? 0) != 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Khoản thu khác (KHÔNG phải học phí)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 6),
                if ((s.otherReceipts.mienGiamKhenThuong ?? 0) != 0)
                  Text('Miễn giảm/khen thưởng: ${_fmtAmount(s.otherReceipts.mienGiamKhenThuong)}',
                      style: const TextStyle(fontSize: 12)),
                if ((s.otherReceipts.lePhiKhac ?? 0) != 0)
                  Text('Lệ phí khác: ${_fmtAmount(s.otherReceipts.lePhiKhac)}',
                      style: const TextStyle(fontSize: 12)),
                if ((s.otherReceipts.hoanPhi ?? 0) != 0)
                  Text('Hoàn phí: ${_fmtAmount(s.otherReceipts.hoanPhi)}',
                      style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color color;

  const _MiniCard({
    required this.icon,
    required this.label,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sổ công nợ IMS — nguồn RIÊNG, không gộp với summary phía trên ──
class _CongNoCard extends StatelessWidget {
  final CrmCongNo congNo;
  const _CongNoCard({required this.congNo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sổ công nợ (IMS)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 6),
          if (!congNo.computable || congNo.note != null)
            Text(congNo.note ?? 'Chưa có nghĩa vụ học phí được ghi nhận.',
                style: const TextStyle(fontSize: 12, color: Colors.grey))
          else ...[
            Text('Phải nộp: ${_fmtAmount(congNo.phaiNop)}', style: const TextStyle(fontSize: 12)),
            Text('Đã nộp: ${_fmtAmount(congNo.daNop)}', style: const TextStyle(fontSize: 12)),
            Text('Công nợ: ${_fmtAmount(congNo.congNo)}', style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

// ── Transaction Card ────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  final CrmTuitionPayment item;
  const _TransactionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = item;
    final isPaid = (t.soTien ?? 0) > 0;
    final color = isPaid ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final bgColor = isPaid ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);
    final icon = isPaid ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (t.loaiPhieuThu ?? '').trim().isEmpty
                        ? '–'
                        : t.loaiPhieuThu!.trim(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(_fmtDate(t.ngayNop),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  if ((t.ghiChu ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(t.ghiChu!,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            Text(
              _fmtAmount(t.soTien),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
