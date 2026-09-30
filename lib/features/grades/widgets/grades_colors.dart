import 'package:flutter/material.dart';
import '../../../theme/vd_tokens.dart';

/// Colour of a grade letter (the school's 8-band ladder; '' = not bandable,
/// neutral grey).
Color gradeLetterColor(String letter, VdTokens t) => switch (letter) {
      'A' => t.success,
      'B+' || 'B' => t.info,
      'C+' || 'C' => t.accent,
      'D+' || 'D' => t.inkMuted,
      'F' => t.danger,
      _ => t.inkMuted,
    };
