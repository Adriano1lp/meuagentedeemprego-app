import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/legal_versions.dart';
import '../../data/repositories/legal_repository_impl.dart';

class LegalDocumentPanel extends ConsumerStatefulWidget {
  const LegalDocumentPanel({
    super.key,
    required this.doc,
    required this.accepted,
    required this.onAccepted,
    this.enabled = true,
    this.onLoaded,
  });

  final LegalDoc doc;
  final bool accepted;
  final ValueChanged<bool> onAccepted;
  final bool enabled;
  final ValueChanged<bool>? onLoaded;

  @override
  ConsumerState<LegalDocumentPanel> createState() => _LegalDocumentPanelState();
}

class _LegalDocumentPanelState extends ConsumerState<LegalDocumentPanel> {
  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Color(0xFFFDFDF7);

  bool _isLoading = true;
  String? _errorMessage;
  String? _markdown;

  bool get _hasText => (_markdown ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    widget.onLoaded?.call(false);

    try {
      final document = await ref.read(legalRepositoryProvider).fetchDocument(
        widget.doc,
        version: widget.doc.currentVersion,
      );
      if (!mounted) return;
      setState(() {
        _markdown = document.markdown;
        _isLoading = false;
      });
      widget.onLoaded?.call(document.markdown.trim().isNotEmpty);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _markdown = null;
        _isLoading = false;
      });
      widget.onLoaded?.call(false);
      if (widget.accepted) {
        widget.onAccepted(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = widget.doc.currentVersion;
    final canAccept = widget.enabled && _hasText && !_isLoading;

    return Container(
      key: ValueKey('${widget.doc.apiValue}DocumentPanel'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _ink, width: 3),
        boxShadow: const [BoxShadow(color: _ink, offset: Offset(4, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.doc.title,
            style: theme.textTheme.titleMedium?.copyWith(color: _ink),
          ),
          const SizedBox(height: 4),
          Text(
            'GET /legal/${widget.doc.apiValue}?version=$version',
            key: ValueKey('${widget.doc.apiValue}DocumentEndpoint'),
            style: theme.textTheme.bodySmall?.copyWith(color: _ink),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180, minHeight: 96),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _ink, width: 2),
              ),
              child: _buildDocumentBody(theme),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                key: ValueKey('${widget.doc.apiValue}AcceptCheckbox'),
                value: widget.accepted,
                onChanged: canAccept
                    ? (next) => widget.onAccepted(next ?? false)
                    : null,
                side: const BorderSide(color: _ink, width: 2),
                activeColor: const Color(0xFFB6F36A),
                checkColor: _ink,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '${widget.doc.acceptPrefix}${widget.doc.title} (v$version). '
                    'Obrigatorio apos ler o texto acima.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: _ink),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nao foi possivel carregar o documento. Sem o texto vigente nao e possivel aceitar.',
              style: theme.textTheme.bodyMedium?.copyWith(color: _ink),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: _ink),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: widget.enabled ? _load : null,
              child: const Text('Tentar de novo'),
            ),
          ],
        ),
      );
    }

    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectableText(
          _markdown ?? '',
          key: ValueKey('${widget.doc.apiValue}DocumentText'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: _ink,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}
