import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../crm_web/android_photo_picker.dart' show pickPhotosForHandIn;
import 'hand_in_sheet.dart' show PickedFile;

/// Any file for a hand-in (PDF, Word, Excel, …): the system document picker.
Future<List<PickedFile>> pickFilesForHandIn() async {
  final picked = await FilePicker.pickFiles(type: FileType.any);
  return [for (final f in picked) (name: f.name, read: f.readAsBytes)];
}

/// Photos for a hand-in: the system photo picker (image_picker lives in one
/// file, android_photo_picker.dart).
Future<List<PickedFile>> pickPhotoFilesForHandIn() async {
  final picked = await pickPhotosForHandIn();
  return [
    for (final f in picked)
      (name: f.name, read: () => File(f.path).readAsBytes()),
  ];
}
