import 'pdf_file_handler_stub.dart'
    if (dart.library.io) 'pdf_file_handler_io.dart'
    if (dart.library.js_interop) 'pdf_file_handler_web.dart';

abstract class PdfFileHandler {
  Future<void> openPdf({
    required List<int> bytes,
    required String fileName,
  });
}

PdfFileHandler createPdfFileHandler() => createPlatformPdfFileHandler();
