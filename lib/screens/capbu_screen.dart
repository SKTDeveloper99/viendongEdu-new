import 'package:flutter/material.dart';
import '../models/crm_money_capbu.dart';
import '../services/crm_money_api.dart';
import '../services/crm_session_guard.dart';
import '../theme/vd_tokens.dart';

part 'widgets/capbu_widgets.dart';

String _fmtDate(DateTime? d) => d == null
    ? '–'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _fmtAmount(num? v) =>
    v == null ? 'chưa có dữ liệu' : '${v.toString()} đ';

// Thay ApiService.getCapBu (IMS hocvien/capbu) bằng CrmMoneyApi.getCapBu
// (GET /api/student/me/capbu) — mirror IMS nguyên văn, không có luật CRM.
class CapBuScreen extends StatefulWidget {
  const CapBuScreen({super.key});

  @override
  State<CapBuScreen> createState() => _CapBuScreenState();
}

class _CapBuScreenState extends State<CapBuScreen> {
  List<CrmCapBuItem> _items = [];
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
      final data = await CrmMoneyApi.getCapBu();
      if (!mounted) return;
      setState(() {
        _items = data.items;
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
                  IconButton(
                    tooltip: 'Quay lại',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: context.vd.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cấp bù',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: context.vd.onPrimary,
                      ),
                    ),
                  ),
                  if (!_loading && _error == null && _items.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.vd.headerBottom,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_items.length} hóa đơn',
                        style: TextStyle(
                          color: context.vd.onHeader,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.vd.accent,
                      ),
                    )
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
                              backgroundColor: context.vd.accent,
                            ),
                            child: Text(
                              'Thử lại',
                              style: TextStyle(color: context.vd.onPrimary),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance,
                            size: 64,
                            color: context.vd.inkFaint,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Không có hóa đơn cấp bù',
                            style: TextStyle(color: context.vd.inkFaint),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetch,
                      color: context.vd.accent,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _CapBuCard(
                          item: _items[i],
                          onTap: () => showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => SizedBox(
                              height: MediaQuery.of(ctx).size.height * 0.75,
                              child: _CapBuDetailSheet(item: _items[i]),
                            ),
                          ),
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
