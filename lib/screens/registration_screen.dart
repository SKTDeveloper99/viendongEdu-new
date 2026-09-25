import 'package:flutter/material.dart';
import '../models/crm_registration_models.dart';
import '../services/crm_registration_api.dart';
import '../services/crm_session_guard.dart';

String _fmtDate(DateTime? d) => d == null
    ? '–'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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

  @override
  void initState() {
    super.initState();
    _fetchPeriods();
  }

  Future<void> _fetchPeriods() async {
    setState(() { _loadingPeriods = true; _error = null; });
    try {
      final periods = await CrmRegistrationApi.getPeriods();
      if (!mounted) return;
      setState(() {
        _periods = periods;
        _loadingPeriods = false;
      });
      if (periods.isNotEmpty) {
        // Ưu tiên đợt đang mở; không có thì lấy đợt đầu (mới nhất trả về).
        final open = periods.where((p) => p.isOpen);
        _selectPeriod(open.isNotEmpty ? open.first : periods.first);
      }
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(() { _loadingPeriods = false; _error = e.toString(); });
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
    setState(() { _loadingData = true; _error = null; });
    try {
      final periodId = period.periodId;
      final offeringsFuture = periodId == null
          ? Future.value(const CrmRegistrationOfferingsPage())
          : CrmRegistrationApi.getOfferings(
              periodId: periodId,
              allSections: _allSections,
            );
      final resultsFuture = CrmRegistrationApi.getResults(semester: period.semesterCode);
      final offeringsPage = await offeringsFuture;
      final results = await resultsFuture;
      if (!mounted) return;
      setState(() {
        _offeringsPage = offeringsPage;
        _results = results;
        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (await handleCrmAuthError(context, e)) return;
      setState(() { _loadingData = false; _error = e.toString(); });
    }
  }

  Future<void> _toggleAllSections(bool value) async {
    setState(() => _allSections = value);
    await _loadOfferingsAndResults();
  }

  bool _isEmsRegistered(String offeringId) => _results.any(
        (r) => r.isEmsRequest && r.offeringId == offeringId && r.status != 'withdrawn',
      );

  CrmRegistrationResult? _emsResultFor(String offeringId) {
    for (final r in _results) {
      if (r.isEmsRequest && r.offeringId == offeringId && r.status != 'withdrawn') return r;
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
        _showSnack(res.alreadyWithdrawn
            ? 'Đã hủy đăng ký từ trước.'
            : 'Đã hủy đăng ký ${offering.subjectName ?? ''}');
      } else {
        final res = await CrmRegistrationApi.register(offering.offeringId);
        if (!mounted) return;
        setState(() {
          _results.add(CrmRegistrationResult(
            id: res.id,
            offeringId: offering.offeringId,
            subjectName: offering.subjectName,
            subjectCode: offering.subjectCode,
            classCode: offering.classCode,
            status: res.status ?? 'pending',
            submittedAt: res.submittedAt,
            source: 'ems_request',
            syncedToIms: false,
          ));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red[700] : Colors.green[700],
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE65100), Color(0xFFFF8C00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Đăng ký môn học',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_loadingPeriods && _periods.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CrmRegistrationPeriod>(
                          value: _selectedPeriod,
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          iconEnabledColor: const Color(0xFFE65100),
                          icon: const Icon(Icons.expand_more_rounded, size: 20),
                          isDense: true,
                          style: const TextStyle(
                              color: Color(0xFF333333),
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          selectedItemBuilder: (_) => _periods
                              .map((p) => Center(
                                    child: Text(p.periodName ?? p.periodCode ?? '–',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Color(0xFFE65100),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                  ))
                              .toList(),
                          items: _periods
                              .map((p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p.periodName ?? p.periodCode ?? '–',
                                        overflow: TextOverflow.ellipsis),
                                  ))
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

            if (_selectedPeriod != null) _buildPeriodInfo(_selectedPeriod!),

            Expanded(
              child: _loadingPeriods
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFE65100)))
                  : _error != null && _periods.isEmpty
                      ? _buildError()
                      : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodInfo(CrmRegistrationPeriod period) {
    final open = period.isOpen;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: open ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
        border: Border.all(
            color: open ? const Color(0xFF4CAF50) : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            open ? Icons.lock_open_rounded : Icons.lock_rounded,
            color: open ? const Color(0xFF2E7D32) : Colors.grey[600],
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  open ? 'Đang mở đăng ký' : 'Đợt đăng ký đã đóng',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: open ? const Color(0xFF2E7D32) : Colors.grey[800],
                  ),
                ),
                if (period.startAt != null && period.endAt != null)
                  Text(
                    '${_fmtDate(period.startAt)} – ${_fmtDate(period.endAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingData) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFE65100)));
    }
    if (_error != null) return _buildError();
    if (_periods.isEmpty) {
      // Owner rule: no hidden screens — empty data is real, show it plainly.
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Hiện không có đợt đăng ký nào cho học kỳ này.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final page = _offeringsPage;
    final offerings = page?.offerings ?? const <CrmRegistrationOffering>[];
    final curriculumResolved = page?.curriculumResolved ?? true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── Kết quả đã ghi nhận (EMS + IMS) ──
        if (_results.isNotEmpty) ...[
          const Text('Đã đăng ký / đã xếp lớp',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          ..._results.map((r) => _ResultCard(result: r)),
          const SizedBox(height: 16),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Môn học mở đăng ký',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            // "Xem tất cả lớp" — scope=all, bỏ lọc theo chương trình học.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Xem tất cả lớp', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Switch(
                  value: _allSections,
                  activeThumbColor: const Color(0xFFE65100),
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
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFFE65100)),
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
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Center(
              child: Text('Không có môn học mở đăng ký cho đợt này.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...offerings.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildOfferingCard(o),
              )),
      ],
    );
  }

  Widget _buildOfferingCard(CrmRegistrationOffering mon) {
    final isRegistered = _isEmsRegistered(mon.offeringId);
    final isProcessing = _processing.contains(mon.offeringId);
    final canRegister = _selectedPeriod?.isOpen ?? false;
    final full = mon.maxSize != null &&
        mon.registeredCount != null &&
        mon.registeredCount! >= mon.maxSize!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRegistered
              ? const Color(0xFF4CAF50)
              : const Color(0xFFEEEEEE),
          width: isRegistered ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    mon.subjectName ?? '–',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                if (isRegistered) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Đã gửi (EMS)',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _infoRow(Icons.tag_rounded, mon.subjectCode ?? '–'),
            _infoRow(Icons.person_outline_rounded,
                (mon.teacherName ?? '').isNotEmpty ? mon.teacherName! : '–'),
            _infoRow(Icons.location_on_outlined, mon.facilityName ?? '–'),
            _infoRow(
              Icons.star_border_rounded,
              '${mon.credits ?? '–'} tín chỉ'
              '${(mon.creditsLt ?? 0) > 0 ? '  ·  LT: ${mon.creditsLt}' : ''}'
              '${(mon.creditsTh ?? 0) > 0 ? '  ·  TH: ${mon.creditsTh}' : ''}',
            ),
            if (mon.maxSize != null)
              _infoRow(Icons.groups_outlined,
                  'Sĩ số: ${mon.registeredCount ?? 0}/${mon.maxSize}'),
            // Chỉ có ý nghĩa khi đang "Xem tất cả lớp" (chế độ mặc định đã
            // tự lọc theo chương trình rồi, mọi thẻ đều trong chương trình).
            if (_allSections && mon.inMyCurriculum == false)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ngoài chương trình học của bạn',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: isProcessing
                  ? const Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Color(0xFFE65100)),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: (canRegister && !(full && !isRegistered))
                          ? () => _toggleDangKy(mon)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRegistered
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFE65100),
                        foregroundColor: isRegistered
                            ? const Color(0xFFC62828)
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        disabledBackgroundColor: Colors.grey.shade200,
                      ),
                      child: Text(
                        isRegistered
                            ? 'Hủy đăng ký'
                            : full
                                ? 'Lớp đã đầy'
                                : 'Đăng ký',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFFE65100)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_error ?? 'Có lỗi xảy ra',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchPeriods,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100)),
                child: const Text('Thử lại',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
}

// ── Card kết quả đăng ký/xếp lớp — luôn ghi rõ nguồn ──
class _ResultCard extends StatelessWidget {
  final CrmRegistrationResult result;
  const _ResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final isEms = result.isEmsRequest;
    final color = isEms ? const Color(0xFF2E7D32) : const Color(0xFF1565C0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result.subjectName ?? result.classCode ?? '–',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(result.classCode ?? '–',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (isEms && !result.syncedToIms) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Ghi nhận ở EMS, chưa gửi tới Phòng Đào tạo (IMS).',
                    style: TextStyle(fontSize: 10, color: Colors.orange, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(result.sourceLabel,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
