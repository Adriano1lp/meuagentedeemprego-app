/// Basename accepted for `GET /users/me/files/{nome}`.
///
/// Rejects traversal (`..`, `/`, `\`) and anything that is not a single
/// safe file name. Blank and non-usable values stay null so the UI does
/// not render a download CTA.
String? sanitizeCvFileName(String? raw) {
  if (raw == null) {
    return null;
  }

  final name = raw.trim();
  if (name.isEmpty || name == '.' || name == '..') {
    return null;
  }
  if (name.contains('..') ||
      name.contains('/') ||
      name.contains('\\') ||
      name.contains('%') ||
      name.contains('\u0000')) {
    return null;
  }
  if (!_safeCvFileName.hasMatch(name)) {
    return null;
  }
  return name;
}

final RegExp _safeCvFileName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$');
