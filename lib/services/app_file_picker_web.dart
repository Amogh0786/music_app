import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'app_file_picker.dart';

Future<AppPickedFile?> pickMusicArchiveOrCsv() async {
  final completer = Completer<AppPickedFile?>();
  try {
    final uploadInput = web.HTMLInputElement()
      ..type = 'file'
      ..accept = '.csv,.zip,text/csv,application/zip,application/x-zip-compressed';

    uploadInput.addEventListener(
      'change',
      ((web.Event event) {
        final files = uploadInput.files;
        if (files != null && files.length > 0) {
          final file = files.item(0)!;
          final reader = web.FileReader();

          reader.addEventListener(
            'loadend',
            ((web.Event e) {
              final result = reader.result;
              if (result != null) {
                final bytes = (result as JSArrayBuffer).toDart.asUint8List();
                if (!completer.isCompleted) {
                  completer.complete(AppPickedFile(
                    name: file.name,
                    bytes: bytes,
                  ));
                }
              } else {
                if (!completer.isCompleted) completer.complete(null);
              }
            }).toJS,
          );

          reader.addEventListener(
            'error',
            ((web.Event e) {
              if (!completer.isCompleted) completer.complete(null);
            }).toJS,
          );

          reader.readAsArrayBuffer(file);
        } else {
          if (!completer.isCompleted) completer.complete(null);
        }
      }).toJS,
    );

    uploadInput.click();
  } catch (_) {
    if (!completer.isCompleted) completer.complete(null);
  }

  return completer.future;
}
