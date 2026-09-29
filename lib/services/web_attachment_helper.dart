import 'dart:typed_data';
import 'web_attachment_helper_stub.dart'
    if (dart.library.js_interop) 'web_attachment_helper_web.dart'
    as helper;

/// Downloads a binary blob to the user's browser downloads directory (Web only, no-op on Native).
void downloadBlobWeb(List<int> bytes, String filename) =>
    helper.downloadBlobWeb(bytes, filename);

/// Copies an image to the user's system clipboard (Web only, no-op on Native).
Future<bool> copyImageToClipboardWeb(Uint8List imageBytes) =>
    helper.copyImageToClipboardWeb(imageBytes);
