import 'dart:typed_data';

/// No-op stub for native platforms where file paths and OS intents handle attachments.
void downloadBlobWeb(List<int> bytes, String filename) {
  // No-op on mobile/desktop platforms
}

/// No-op stub for native platforms where system clipboard handles native sharing.
Future<bool> copyImageToClipboardWeb(Uint8List imageBytes) async {
  return false;
}
