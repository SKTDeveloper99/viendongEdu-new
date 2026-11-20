import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../services/upload_sender.dart' show PhotoShrink;

// The only file that uses image_picker (owner to confirm before any build).
// Removing the package = delete this file, the one line in
// crm_web_routes.dart that passes [pickPhotosForWebView] (Android then does
// nothing on the page's attach button; iOS is unaffected) and the default
// picker of the hand-in sheet (lib/features/work/hand_in_sheet.dart), whose
// "Đính kèm ảnh" then has nothing to open.

/// Photos for a hand-in (native "Đính kèm ảnh", iOS and Android): the system
/// photo picker, several at once. Returns (path, name); empty = cancelled.
/// Shrunk on the phone to [PhotoShrink] before anything is sent.
Future<List<({String path, String name})>> pickPhotosForHandIn({
  ImagePicker? picker,
}) async {
  final picked = await (picker ?? ImagePicker()).pickMultiImage(
    maxWidth: PhotoShrink.maxEdge,
    maxHeight: PhotoShrink.maxEdge,
    imageQuality: PhotoShrink.quality,
  );
  return [for (final f in picked) (path: f.path, name: f.name)];
}

/// "Chụp ảnh": one photo from the camera (null = cancelled). Throws when the
/// phone has no camera or the person refused it. Shrunk like the above.
Future<({String path, String name})?> takePhotoForHandIn({
  ImagePicker? picker,
}) async {
  final shot = await (picker ?? ImagePicker()).pickImage(
    source: ImageSource.camera,
    maxWidth: PhotoShrink.maxEdge,
    maxHeight: PhotoShrink.maxEdge,
    imageQuality: PhotoShrink.quality,
  );
  return shot == null ? null : (path: shot.path, name: shot.name);
}

/// Android web view `<input type=file>`: photos only (camera when the page
/// asks for capture, else the system photo picker). Returns file URIs; an
/// empty list cancels. Documents (PDF, Word) cannot be chosen here.
Future<List<String>> pickPhotosForWebView(FileSelectorParams params) async {
  final picker = ImagePicker();
  final wantsImages =
      params.acceptTypes.isEmpty ||
      params.acceptTypes.every((t) => t.isEmpty || t.startsWith('image/'));
  if (!wantsImages) return const [];
  try {
    if (params.isCaptureEnabled) {
      final shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      return shot == null ? const [] : [Uri.file(shot.path).toString()];
    }
    if (params.mode == FileSelectorMode.openMultiple) {
      final many = await picker.pickMultiImage(imageQuality: 85);
      return [for (final f in many) Uri.file(f.path).toString()];
    }
    final one = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    return one == null ? const [] : [Uri.file(one.path).toString()];
  } catch (_) {
    return const []; // camera refused or picker failed: nothing attached
  }
}
