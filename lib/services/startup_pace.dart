/// Spreads the first requests from many phones across a short window.
/// This is only load smoothing; server capacity and rate limiting remain authoritative.
class StartupPace {
  StartupPace._();

  static Duration forAccount(String account, {required int windowMs}) {
    var hash = 0;
    for (final unit in account.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return Duration(milliseconds: hash % windowMs);
  }
}
