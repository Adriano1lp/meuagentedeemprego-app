import 'package:flutter/material.dart';

import '../../data/legal_versions.dart';
import '../screens/legal_document_screen.dart';

class LegalAcceptCheckbox extends StatelessWidget {
  const LegalAcceptCheckbox({
    super.key,
    required this.doc,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final LegalDoc doc;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  static const Color _ink = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          key: ValueKey('${doc.apiValue}AcceptCheckbox'),
          value: value,
          onChanged: enabled ? (next) => onChanged(next ?? false) : null,
          side: const BorderSide(color: _ink, width: 2),
          activeColor: const Color(0xFFB6F36A),
          checkColor: _ink,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  doc.acceptPrefix,
                  style: theme.textTheme.bodyMedium?.copyWith(color: _ink),
                ),
                GestureDetector(
                  key: ValueKey('open${_titleCase(doc.apiValue)}Link'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LegalDocumentScreen(doc: doc),
                      ),
                    );
                  },
                  child: Text(
                    '${doc.title} (v${doc.currentVersion})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _ink,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '. Obrigatorio.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: _ink),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }
}
