import 'package:flutter/material.dart';

/// Accent used across the grades screen (unchanged from the legacy screen).
const Color kGradesOrange = Color(0xFFE65100);

/// Colour of a grade letter (the school's 8-band ladder; '' = not bandable,
/// neutral grey).
Color gradeLetterColor(String letter) => switch (letter) {
      'A' => const Color(0xFF4CAF50),
      'B+' || 'B' => const Color(0xFF2196F3),
      'C+' || 'C' => const Color(0xFFFF9800),
      'D+' || 'D' => Colors.grey,
      'F' => const Color(0xFFF44336),
      _ => Colors.grey,
    };
