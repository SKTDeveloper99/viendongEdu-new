/// Remembers whether the "must read" prompt was already raised in this app
/// process. The prompt shows at most once per session; logging out resets it
/// so a different student on the same process still gets theirs.
class MustReadGate {
  bool _shown = false;

  /// One gate for the whole app process (what the screen uses by default).
  static final MustReadGate shared = MustReadGate();

  bool get shown => _shown;

  /// Marks the prompt as shown. Returns false if it already was.
  bool tryShow() {
    if (_shown) return false;
    _shown = true;
    return true;
  }

  void reset() => _shown = false;
}
