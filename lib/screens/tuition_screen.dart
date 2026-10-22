import '../components/skeleton.dart';
import 'package:flutter/material.dart';
import '../models/crm_money_tuition.dart';
import '../services/crm_money_api.dart';
import '../services/crm_session_guard.dart';
import '../theme/vd_tokens.dart';
import '../components/tuition_notes.dart';

part 'widgets/tuition_widgets.dart';

// LUẬT TIỀN: hiện NGUYÊN VĂN số máy chủ; null = "Đang đối chiếu", không bao giờ 0.
String _fmtAmount(int? amount) {
  if (amount == null) return 'Đang đối chiếu';
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
    setState(() {
      _loading = true;
      _error = null;
    });
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
      if (await handleCrmAuthError(context, e)) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final payments = _tuition?.payments ?? const <CrmTuitionPayment>[];
    final summary = _tuition?.summary;

    return Scaffold(
      backgroundColor: context.vd.bg,
      body: SafeArea(
        top: false,
        child: Column(
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
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  _BackButton(),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Học phí',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.vd.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _loading
                  ? skeletonList(accentColor: context.vd.primary)
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: context.vd.inkFaint,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(color: context.vd.inkFaint),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.vd.primary,
                            ),
                            child: Text(
                              'Thử lại',
                              style: TextStyle(color: context.vd.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: context.vd.primary,
                      onRefresh: _fetch,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TuitionNotices(
                              response: _tuition,
                            ), // M-53 + bản lưu
                            // ── Summary (từ summary đã áp luật, không tự tính) ──
                            _SummarySection(summary: summary),
                            const SizedBox(height: 12),
                            // M-52: bảng kê đã là sổ IMS — không hiện số thứ hai.
                            if (_congNo != null && summary?.source != 'bang_ke')
                              _CongNoCard(congNo: _congNo!),
                            const SizedBox(height: 20),

                            // ── Section label ──
                            const Text(
                              'Lịch sử giao dịch',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // ── Transaction list ──
                            if (payments.isEmpty)
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        size: 64,
                                        color: context.vd.inkFaint,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Không có giao dịch',
                                        style: TextStyle(
                                          color: context.vd.inkFaint,
                                        ),
                                      ),
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
        ),
      ),
    );
  }
}
