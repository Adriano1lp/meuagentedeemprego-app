import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'pdf_file_handler.dart';

class _WebPdfFileHandler implements PdfFileHandler {
  @override
  Future<void> openPdf({
    required List<int> bytes,
    required String fileName,
  }) async {
    final uint8List = Uint8List.fromList(bytes);
    final blob = web.Blob(
      [uint8List.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    final objectUrl = web.URL.createObjectURL(blob);

    try {
      final anchor = web.HTMLAnchorElement()
        ..href = objectUrl
        ..target = '_blank'
        ..download = fileName
        ..style.display = 'none';

      web.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } finally {
      web.URL.revokeObjectURL(objectUrl);
    }
  }
}

PdfFileHandler createPlatformPdfFileHandler() => _WebPdfFileHandler();
