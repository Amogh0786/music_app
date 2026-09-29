import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Downloads a binary blob directly to listener's local filesystem in the browser.
void downloadBlobWeb(List<int> bytes, String filename) {
  try {
    final uint8 = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    final blob = web.Blob(
      [uint8.toJS].toJS,
      web.BlobPropertyBag(type: 'application/zip'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = filename
      ..style.display = 'none';

    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(url);
  } catch (e) {
    debugPrint('[WebAttachmentHelper] Blob download error: $e');
  }
}

/// Copies raw PNG image bytes to browser clipboard for direct pasting into webmail composers.
Future<bool> copyImageToClipboardWeb(Uint8List imageBytes) async {
  try {
    final blob = web.Blob(
      [imageBytes.toJS].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );
    final itemData = {'image/png': blob}.jsify() as JSObject;
    final item = web.ClipboardItem(itemData);
    await web.window.navigator.clipboard.write([item].toJS).toDart;
    return true;
  } catch (e) {
    debugPrint('[WebAttachmentHelper] Clipboard image copy error: $e');
    return false;
  }
}
