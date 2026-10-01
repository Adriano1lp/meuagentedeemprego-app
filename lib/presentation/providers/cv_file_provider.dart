import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cv_file_name.dart';
import '../../data/repositories/cv_file_repository.dart';
import '../utils/pdf_file_handler.dart';
import 'session_provider.dart';

typedef CvFileDownload = Future<void> Function(String fileName);

final cvFileDownloadProvider = Provider<CvFileDownload>((ref) {
  final repository = CvFileRepository(
    tokenStore: ref.watch(secureTokenStoreProvider),
  );
  final opener = createPdfFileHandler();
  return (fileName) async {
    final safeName = sanitizeCvFileName(fileName);
    if (safeName == null) {
      throw const CvDownloadException();
    }
    final bytes = await repository.downloadBytes(safeName);
    await opener.openPdf(bytes: bytes, fileName: safeName);
  };
});
