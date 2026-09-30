import 'package:flutter/material.dart';
import '../theme/vd_tokens.dart';

void showSuccessSnack(BuildContext context, String msg, {Duration duration = const Duration(seconds: 3)}) {
  final h = MediaQuery.of(context).size.height;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: context.vd.onPrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: TextStyle(color: context.vd.onPrimary, fontSize: 14))),
        ],
      ),
      backgroundColor: context.vd.success,
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
          Icon(Icons.error_rounded, color: context.vd.onPrimary, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: TextStyle(color: context.vd.onPrimary, fontSize: 14))),
        ],
      ),
      backgroundColor: context.vd.danger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.only(bottom: h - 160, left: 16, right: 16),
      duration: duration,
    ));
}
