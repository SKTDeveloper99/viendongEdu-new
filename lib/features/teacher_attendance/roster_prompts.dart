import '../../services/ems_api_service.dart';

/// What the save flow asks of the view. The view model never shows a dialog
/// or a snackbar itself; it awaits these.
class RosterPrompts {
  const RosterPrompts({
    required this.confirmUnmarked,
    required this.askReasons,
    required this.toast,
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
}
