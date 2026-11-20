// Photos are shrunk on the phone before they are sent: camera and gallery
// picks ask image_picker for a 2000 px longest edge and JPEG quality 80.
//
//   flutter test test/photo_shrink_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:viendongedu2_flutter/features/crm_web/android_photo_picker.dart';
import 'package:viendongedu2_flutter/services/upload_sender.dart';

class _Asked {
  final double? maxWidth, maxHeight;
  final int? quality;
  final ImageSource? source;
  const _Asked(this.maxWidth, this.maxHeight, this.quality, [this.source]);
}

class _FakePicker extends ImagePicker {
  final asked = <_Asked>[];

  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    asked.add(_Asked(maxWidth, maxHeight, imageQuality));
    return [XFile('/tmp/scaled_1.jpg', name: 'scaled_1.jpg')];
  }

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    asked.add(_Asked(maxWidth, maxHeight, imageQuality, source));
    return XFile('/tmp/shot.jpg', name: 'shot.jpg');
  }
}

void main() {
  test('gallery photos ask for 2000 px and quality 80', () async {
    final p = _FakePicker();
    final got = await pickPhotosForHandIn(picker: p);
    expect(got.single.path, '/tmp/scaled_1.jpg');
    final a = p.asked.single;
    expect(a.maxWidth, PhotoShrink.maxEdge);
    expect(a.maxHeight, PhotoShrink.maxEdge);
    expect(a.quality, PhotoShrink.quality);
  });

  test('a camera shot asks for the same', () async {
    final p = _FakePicker();
    final got = await takePhotoForHandIn(picker: p);
    expect(got?.path, '/tmp/shot.jpg');
    final a = p.asked.single;
    expect(a.source, ImageSource.camera);
    expect(a.maxWidth, 2000);
    expect(a.maxHeight, 2000);
    expect(a.quality, 80);
  });
}
