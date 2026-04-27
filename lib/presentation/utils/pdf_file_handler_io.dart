import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'pdf_file_handler.dart';

class _IoPdfFileHandler implements PdfFileHandler {
  @override
  Future<void> openPdf({
    required List<int> bytes,
    required String fileName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);

    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}

PdfFileHandler createPlatformPdfFileHandler() => _IoPdfFileHandler();
