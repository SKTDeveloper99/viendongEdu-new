import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

// The only file that uses image_picker (owner to confirm before any build).
// Removing the package = delete this file and the one line in
// crm_web_routes.dart that passes [pickPhotosForWebView]; Android then
// does nothing on the page's attach button (iOS is unaffected).

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
