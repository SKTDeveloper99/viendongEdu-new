import 'package:flutter/material.dart';
import '../models/crm_registration_models.dart';
import '../components/student_registration_cards.dart';
import '../services/crm_registration_api.dart';
import '../services/crm_session_guard.dart';
import '../theme/vd_tokens.dart';

// ── Screen ─────────────────────────────────────────────
// Thay ApiService.getDotDangKy/getMonHocDuKien/getKetQuaDangKy/
// postDangKyMon/deleteDangKyMon (IMS) bằng CrmRegistrationApi (đọc:
// docs/api/mobile-ims-replacement-S3.md; ghi: .../S5.md).
//
// `offering_id` bây giờ là id LMH IMS (`tbl_qldt_tkb_lopmonhoc.id`), KHÔNG
// còn là `mhid` (monhocid) như app IMS cũ. Đăng ký được GHI Ở EMS, CHƯA gửi
// lên IMS — màn hình phải nói rõ điều đó, không giấu (owner ruling
// 2026-09-24).
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  List<CrmRegistrationPeriod> _periods = [];
  CrmRegistrationPeriod? _selectedPeriod;
  CrmRegistrationOfferingsPage? _offeringsPage;
  List<CrmRegistrationResult> _results = [];

  final Set<String> _processing = {};

  /// Nút "Xem tất cả lớp" (scope=all) — mặc định false: chỉ lớp trong
  /// chương trình học của chính học viên và chưa đạt.
  bool _allSections = false;

  bool _loadingPeriods = true;
  bool _loadingData = false;
  String? _error;
  int _periodRequest = 0;
  int _dataRequest = 0;

  @override
  void initState() {
    super.initState();
    _fetchPeriods();
  }

  Future<void> _fetchPeriods() async {
    final request = ++_periodRequest;
    ++_dataRequest;
    final selectedId = _selectedPeriod?.periodId;
    setState(() {
      _loadingPeriods = true;
      _selectedPeriod = null;
      _offeringsPage = null;
      _results = [];
      _error = null;
    });
    try {
      final periods = await CrmRegistrationApi.getPeriods();
      if (!mounted || request != _periodRequest) return;
      setState(() {
        _periods = periods;
        _loadingPeriods = false;
      });
      if (periods.isNotEmpty) {
        // Ưu tiên đợt đang mở; không có thì lấy đợt đầu (mới nhất trả về).
        final open = periods.where((p) => p.isOpen);
        final previous = periods.where((p) => p.periodId == selectedId);
        await _selectPeriod(
          previous.isNotEmpty
              ? previous.first
              : open.isNotEmpty
              ? open.first
              : periods.first,
        );
      }
    } catch (e) {
      if (!mounted || request != _periodRequest) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(() {
        _loadingPeriods = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectPeriod(CrmRegistrationPeriod period) async {
    setState(() {
      _selectedPeriod = period;
      _allSections = false;
      _loadingData = true;
      _offeringsPage = null;
      _results = [];
      _error = null;
    });
    await _loadOfferingsAndResults();
  }

  /// Nạp lại danh sách lớp + kết quả cho đợt đang chọn — dùng cả khi đổi
  /// đợt lẫn khi bật/tắt "Xem tất cả lớp".
  Future<void> _loadOfferingsAndResults() async {
    final period = _selectedPeriod;
    if (period == null) return;
    final request = ++_dataRequest;
    setState(() {
      _loadingData = true;
      _error = null;
    });
    try {
      final periodId = period.periodId;
      final offeringsFuture = periodId == null
          ? Future.value(const CrmRegistrationOfferingsPage())
          : CrmRegistrationApi.getOfferings(
              periodId: periodId,
              allSections: _allSections,
            );
      final resultsFuture = CrmRegistrationApi.getResults(
        semester: period.semesterCode,
      );
      final data = await Future.wait<Object>([offeringsFuture, resultsFuture]);
      final offeringsPage = data[0] as CrmRegistrationOfferingsPage;
      final results = data[1] as List<CrmRegistrationResult>;
      if (!mounted || request != _dataRequest) return;
      setState(() {
        _offeringsPage = offeringsPage;
        _results = results;
        _loadingData = false;
      });
    } catch (e) {
      if (!mounted || request != _dataRequest) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(() {
        _loadingData = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleAllSections(bool value) async {
    setState(() => _allSections = value);
    await _loadOfferingsAndResults();
  }

  bool _isEmsRegistered(String offeringId) => _results.any(
    (r) =>
        r.isEmsRequest && r.offeringId == offeringId && r.status != 'withdrawn',
  );

  CrmRegistrationResult? _emsResultFor(String offeringId) {
    for (final r in _results) {
      if (r.isEmsRequest &&
          r.offeringId == offeringId &&
          r.status != 'withdrawn') {
        return r;
      }
    }
    return null;
  }

  Future<void> _toggleDangKy(CrmRegistrationOffering offering) async {
    final period = _selectedPeriod;
    if (period == null) return;
    if (!period.isOpen) {
      _showSnack('Đợt đăng ký chưa mở hoặc đã kết thúc.', isError: true);
      return;
    }

    setState(() => _processing.add(offering.offeringId));
    final existing = _emsResultFor(offering.offeringId);
    try {
      if (existing != null && existing.id != null) {
        final res = await CrmRegistrationApi.cancel(existing.id!);
        if (!mounted) return;
        setState(() {
          _results.removeWhere((r) => r.id == existing.id);
        });
        _showSnack(
          res.alreadyWithdrawn
              ? 'Đã hủy đăng ký từ trước.'
              : 'Đã hủy đăng ký ${offering.subjectName ?? ''}',
        );
      } else {
        final res = await CrmRegistrationApi.register(offering.offeringId);
        if (!mounted) return;
        setState(() {
          _results.add(
            CrmRegistrationResult(
              id: res.id,
              offeringId: offering.offeringId,
              subjectName: offering.subjectName,
              subjectCode: offering.subjectCode,
              classCode: offering.classCode,
              status: res.status ?? 'pending',
              submittedAt: res.submittedAt,
              source: 'ems_request',
              syncedToIms: false,
            ),
          );
        });
        _showSnack(
          'Đã gửi đăng ký ${offering.subjectName ?? ''} lên EMS. '
          'Chưa được gửi tới Phòng Đào tạo (IMS) — đây chỉ là ghi nhận ở EMS.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      // Hiện nguyên văn lỗi máy chủ (đợt đóng / lớp đầy / đã đăng ký).
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _processing.remove(offering.offeringId));
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? context.vd.danger : context.vd.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.arrow_back_ios,
                          color: context.vd.onPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Đăng ký môn học',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: context.vd.onPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_loadingPeriods && _periods.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.only(
                        left: 14,
                        right: 6,
                        top: 6,
                        bottom: 6,
                      ),
                      decoration: BoxDecoration(
                        color: context.vd.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: context.vd.shadow,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CrmRegistrationPeriod>(
                          value: _selectedPeriod,
                          dropdownColor: context.vd.surface,
                          borderRadius: BorderRadius.circular(14),
                          iconEnabledColor: context.vd.primary,
                          icon: const Icon(Icons.expand_more_rounded, size: 20),
                          isDense: true,
                          style: TextStyle(
                            color: context.vd.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          selectedItemBuilder: (_) => _periods
                              .map(
                                (p) => Center(
                                  child: Text(
                                    p.periodName ?? p.periodCode ?? '–',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.vd.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          items: _periods
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p,
                                  child: Text(
                                    p.periodName ?? p.periodCode ?? '–',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (p) {
                            if (p != null) _selectPeriod(p);
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),

            if (_selectedPeriod != null)
              RegistrationPeriodCard(period: _selectedPeriod!),

            Expanded(
              child: _loadingPeriods
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.vd.primary,
                      ),
                    )
                  : _error != null && _periods.isEmpty
                  ? _buildError()
                  : RefreshIndicator(
                      onRefresh: _fetchPeriods,
                      child: _buildBody(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingData) {
      return Center(
        child: CircularProgressIndicator(color: context.vd.primary),
      );
    }
    if (_error != null) return _buildError();
    if (_periods.isEmpty) {
      // Owner rule: no hidden screens — empty data is real, show it plainly.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Hiện không có đợt đăng ký nào cho học kỳ này.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.vd.inkFaint),
            ),
          ),
        ],
      );
    }

    final page = _offeringsPage;
    final offerings = page?.offerings ?? const <CrmRegistrationOffering>[];
    final curriculumResolved = page?.curriculumResolved ?? true;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── Kết quả đã ghi nhận (EMS + IMS) ──
        if (_results.isNotEmpty) ...[
          const Text(
            'Đã đăng ký / đã xếp lớp',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ..._results.map((r) => RegistrationResultCard(result: r)),
          const SizedBox(height: 16),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Môn học mở đăng ký',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            // "Xem tất cả lớp" — scope=all, bỏ lọc theo chương trình học.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Xem tất cả lớp',
                  style: TextStyle(fontSize: 12, color: context.vd.inkFaint),
                ),
                Switch(
                  value: _allSections,
                  activeThumbColor: context.vd.primary,
                  onChanged: _loadingData ? null : _toggleAllSections,
                ),
              ],
            ),
          ],
        ),

        if (!_allSections && !curriculumResolved)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.vd.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: context.vd.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Không xác định được chương trình học để lọc — đang hiện TOÀN BỘ lớp mở, không riêng chương trình của bạn.',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 4),
        if (offerings.isEmpty)
          Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
              child: Text(
                'Không có môn học mở đăng ký cho đợt này.',
                style: TextStyle(color: context.vd.inkFaint),
              ),
            ),
          )
        else
          ...offerings.map(
            (o) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RegistrationOfferingCard(
                mon: o,
                isRegistered: _isEmsRegistered(o.offeringId),
                isProcessing: _processing.contains(o.offeringId),
                canRegister: _selectedPeriod?.isOpen ?? false,
                allSections: _allSections,
                onToggle: () => _toggleDangKy(o),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: context.vd.inkFaint),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Có lỗi xảy ra',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.vd.inkFaint),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchPeriods,
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
    ),
  );
}

// ── Card kết quả đăng ký/xếp lớp — luôn ghi rõ nguồn ──
