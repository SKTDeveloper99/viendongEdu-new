import 'package:flutter/material.dart';

Future<DateTime?> showVdDatePicker(BuildContext context, DateTime initialDate) =>
    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('vi', 'VN'),
      // Seven 48dp calendar columns cannot fit in a narrow dialog.
      initialEntryMode: MediaQuery.sizeOf(context).width < 400
          ? DatePickerEntryMode.inputOnly
          : DatePickerEntryMode.calendar,
    );
