import 'pdf_file_handler.dart';

class _UnsupportedPdfFileHandler implements PdfFileHandler {
  @override
  Future<void> openPdf({
    required List<int> bytes,
    required String fileName,
  }) async {
    throw UnsupportedError('Abertura de PDF nao suportada nesta plataforma.');
  }
}

PdfFileHandler createPlatformPdfFileHandler() => _UnsupportedPdfFileHandler();
