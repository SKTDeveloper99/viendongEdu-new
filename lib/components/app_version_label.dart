import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../theme/vd_tokens.dart';

/// "Phần mềm Viendongedu phiên bản X.Y.Z (build)" footer line of the profile
/// tabs. The version comes from the installed app (package_info_plus). The
/// line is one fixed-height row from the first frame: until the version loads
/// (or if it cannot be read) it shows just "Phần mềm Viendongedu", so nothing
/// below it moves.
class AppVersionLabel extends StatefulWidget {
  /// Returns "X.Y.Z (build)"; tests inject a fake, production reads
  /// [PackageInfo.fromPlatform].
  final Future<String?> Function()? loadVersion;
  const AppVersionLabel({super.key, this.loadVersion});

  static Future<String?> _fromPlatform() async {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty
        ? info.version
        : '${info.version} (${info.buildNumber})';
  }

  @override
  State<AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<AppVersionLabel> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await (widget.loadVersion ?? AppVersionLabel._fromPlatform)();
      if (mounted && v != null && v.isNotEmpty) setState(() => _version = v);
    } catch (_) {
      // Keep the plain name; a missing version must never break the screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _version;
    return Text(
      v == null ? 'Phần mềm Viendongedu' : 'Phần mềm Viendongedu phiên bản $v',
      style: TextStyle(fontSize: 12, color: context.vd.inkMuted),
      textAlign: TextAlign.center,
    );
  }
}
