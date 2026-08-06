import 'package:flutter/material.dart';

void showSuccessSnack(BuildContext context, String msg, {Duration duration = const Duration(seconds: 3)}) {
  final h = MediaQuery.of(context).size.height;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
      backgroundColor: const Color(0xFF4CAF50),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.only(bottom: h - 160, left: 16, right: 16),
      duration: duration,
    ));
}

void showErrorSnack(BuildContext context, String msg, {Duration duration = const Duration(seconds: 4)}) {
  final h = MediaQuery.of(context).size.height;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 14))),
        ],
      ),
      backgroundColor: const Color(0xFFF44336),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.only(bottom: h - 160, left: 16, right: 16),
      duration: duration,
    ));
}
