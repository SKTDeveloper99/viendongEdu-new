import '../../services/ems_api_service.dart';

/// What the save flow asks of the view. The view model never shows a dialog
/// or a snackbar itself; it awaits these.
class RosterPrompts {
  const RosterPrompts({
    required this.confirmUnmarked,
    required this.askReasons,
    required this.toast,
    this.askOtherReasons,
  });

  /// Lists the undecided students; true = save the [chosen] marks anyway.
  final Future<bool> Function(List<EmsRosterStudent> undecided, int chosen)
  confirmUnmarked;

  /// Reason per punched student, or null when the dialog was dismissed.
  final Future<Map<String, String>?> Function(
    List<EmsPunchedStudent> people,
    Map<String, String> initial,
    String Function(String mssv) nameOf,
  )
  askReasons;

  final void Function(String message, {bool good}) toast;

  /// Reason per "Khác" student (A-25); falls back to [askReasons].
  final Future<Map<String, String>?> Function(
    List<EmsPunchedStudent> people,
    Map<String, String> initial,
    String Function(String mssv) nameOf,
  )?
  askOtherReasons;
}

/// A-25: every "Khác" mark carries a reason before it is sent. Adds the
/// reasons to [notes]; false when the teacher cancelled.
Future<bool> askOtherReasons(
  RosterPrompts ui,
  Map<String, String> marks,
  Map<String, String> notes,
  String Function(String mssv) nameOf,
) async {
  final noReason = marks.entries
      .where((e) => e.value == 'excused' && (notes[e.key] ?? '').trim().isEmpty)
      .map((e) => EmsPunchedStudent(mssv: e.key))
      .toList();
  if (noReason.isEmpty) return true;
  final got = await (ui.askOtherReasons ?? ui.askReasons)(
    noReason,
    notes,
    nameOf,
  );
  if (got == null) return false;
  notes.addAll(got);
  return true;
}
