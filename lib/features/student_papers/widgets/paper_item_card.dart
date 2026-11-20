import 'package:flutter/material.dart';

import '../../../theme/vd_tokens.dart';
import '../papers_api.dart';

String _day(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
String _time(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} ${_day(d)}';

/// One thing the school asks for: its state, what it takes, the deadline,
/// why it was returned, the files already sent and the "Gửi" button.
class PaperItemCard extends StatelessWidget {
  final PaperItem item;
  final bool sending;

  /// Under the button: the upload's line, "Gửi tiếp" (PaperSendState).
  final Widget? footer;
  final VoidCallback? onAdd;
  final void Function(PaperFile f) onOpen;
  const PaperItemCard({
    super.key,
    required this.item,
    required this.sending,
    required this.onAdd,
    required this.onOpen,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final (fg, bg) = switch (item.state) {
      'ok' => (vd.success, vd.successSoft),
      'wait' => (vd.info, vd.infoSoft),
      'bad' => (vd.danger, vd.dangerSoft),
      _ => (vd.warning, vd.warningSoft),
    };
    final addLabel = item.takesPhoto && item.takesFile
        ? 'Gửi ảnh hoặc tệp'
        : item.takesPhoto
        ? 'Gửi ảnh'
        : 'Gửi tệp PDF';
    return Card(
      key: Key('paper-${item.code}'),
      margin: const EdgeInsets.only(bottom: 12),
      color: vd.surfaceAlt,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    item.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: vd.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.stateLabel,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.description, style: TextStyle(color: vd.inkMuted)),
            ],
            const SizedBox(height: 6),
            Text(
              [
                'Nhận: ${item.acceptsLabel}',
                if (item.dueOn != null)
                  '${item.overdue ? 'Quá hạn' : 'Hạn'} ${_day(item.dueOn!)}',
              ].join('  ·  '),
              style: TextStyle(
                fontSize: 13,
                color: item.overdue ? vd.danger : vd.inkFaint,
              ),
            ),
            if (item.reasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Lý do: ${item.reasons.join('; ')}',
                style: TextStyle(color: vd.danger),
              ),
            ],
            for (final f in item.files)
              _FileRow(file: f, onTap: () => onOpen(f)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: Key('paper-add-${item.code}'),
                onPressed: sending ? null : onAdd,
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(sending ? 'Đang gửi…' : addLabel),
                style: OutlinedButton.styleFrom(foregroundColor: vd.primary),
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final PaperFile file;
  final VoidCallback onTap;
  const _FileRow({required this.file, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: file.isPhoto
                    ? Image.network(
                        StudentPapersApi.thumbUrl(file.id),
                        headers: StudentPapersApi.authHeaders,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Icon(Icons.image_outlined, color: vd.inkFaint),
                      )
                    : ColoredBox(
                        color: vd.accentSoft,
                        child: Icon(Icons.picture_as_pdf, color: vd.accent),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: vd.ink),
                  ),
                  Text(
                    [
                      if (file.sentAt != null) 'Gửi ${_time(file.sentAt!)}',
                      file.reviewLabel,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(fontSize: 12, color: vd.inkMuted),
                  ),
                  if (file.rejectReason != null)
                    Text(
                      file.rejectReason!,
                      style: TextStyle(fontSize: 12, color: vd.danger),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
