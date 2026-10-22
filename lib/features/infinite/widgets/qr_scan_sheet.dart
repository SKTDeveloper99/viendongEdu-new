import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../theme/vd_tokens.dart';

/// Camera QR scanner with a typed fallback (no camera, simulator, damaged
/// sticker). Pops the scanned or typed value.
class QrScanSheet extends StatefulWidget {
  const QrScanSheet({super.key, this.hint});
  final String? hint;

  @override
  State<QrScanSheet> createState() => _QrScanSheetState();
}

class _QrScanSheetState extends State<QrScanSheet> {
  final _typed = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _finish(String value) {
    if (_done || value.trim().isEmpty) return;
    _done = true;
    Navigator.of(context).pop(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quét mã QR',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: vd.ink,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 260,
              child: MobileScanner(
                onDetect: (capture) {
                  final v = capture.barcodes
                      .map((b) => b.rawValue)
                      .nonNulls
                      .firstOrNull;
                  if (v != null) _finish(v);
                },
                errorBuilder: (context, error) => ColoredBox(
                  color: vd.surfaceAlt,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Không mở được camera. Nhập dòng chữ dưới mã QR.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: vd.inkMuted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.hint != null) ...[
            const SizedBox(height: 10),
            Text(widget.hint!, style: TextStyle(color: vd.inkMuted)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _typed,
                  // ASCII keyboard: Vietnamese Telex turns "vd" into "Về".
                  keyboardType: TextInputType.visiblePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.characters,
                  onSubmitted: _finish,
                  decoration: const InputDecoration(
                    labelText: 'Mã in dưới QR',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _finish(_typed.text),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
