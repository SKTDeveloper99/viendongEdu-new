import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../crm_web/android_photo_picker.dart' show pickPhotosForHandIn;
import 'hand_in_sheet.dart' show PickedFile;

/// Any file for a hand-in (PDF, Word, Excel, …): the system document picker.
Future<List<PickedFile>> pickFilesForHandIn() async {
  final picked = await FilePicker.pickFiles(type: FileType.any);
  return [
    for (final f in picked)
      (name: f.name, size: f.lengthSync(), read: f.readAsBytes),
  ];
}

/// Photos for a hand-in: the system photo picker (image_picker lives in one
/// file, android_photo_picker.dart).
Future<List<PickedFile>> pickPhotoFilesForHandIn() async {
  final picked = await pickPhotosForHandIn();
  final names = photoNames([for (final f in picked) f.name], DateTime.now());
  return [
    for (var i = 0; i < picked.length; i++)
      (
        name: names[i],
        size: _sizeOf(picked[i].path),
        read: () => File(picked[i].path).readAsBytes(),
      ),
  ];
}

/// Friendly names for picked photos instead of the picker's generated ones
/// ("image_picker_….jpg", "scaled_….jpg"): "Ảnh 17-11 12.40.jpg", then
/// "Ảnh 17-11 12.40 (2).jpg", … keeping each photo's own extension.
List<String> photoNames(List<String> originals, DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      'Ảnh ${two(at.day)}-${two(at.month)} ${two(at.hour)}.${two(at.minute)}';
  return [
    for (var i = 0; i < originals.length; i++)
      '$stamp${i == 0 ? '' : ' (${i + 1})'}${_ext(originals[i])}',
  ];
}

String _ext(String name) {
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot).toLowerCase();
  return ext.length > 1 && ext.length <= 6 ? ext : '.jpg';
}

int? _sizeOf(String path) {
  try {
    return File(path).lengthSync();
  } catch (_) {
    return null;
  }
}
