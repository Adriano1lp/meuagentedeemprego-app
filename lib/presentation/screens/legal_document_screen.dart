import 'package:flutter/material.dart';

import '../../data/legal_versions.dart';
import '../../data/repositories/legal_repository_impl.dart';

class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.doc,
    this.version,
  });

  final LegalDoc doc;
  final String? version;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _yellow = Color(0xFFFFE16A);

  final LegalRepositoryImpl _repository = LegalRepositoryImpl();

  bool _isLoading = true;
  String? _errorMessage;
  String? _markdown;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final document = await _repository.fetchDocument(
        widget.doc,
        version: widget.version ?? widget.doc.currentVersion,
      );
      if (!mounted) return;
      setState(() {
        _markdown = document.markdown;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = widget.version ?? widget.doc.currentVersion;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.doc.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _brutalBox(_yellow),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.doc.title,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'GET /legal/${widget.doc.apiValue}?version=$version',
                      style: theme.textTheme.bodySmall?.copyWith(color: _ink),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _brutalBox(_paper),
                child: _buildBody(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _errorMessage!,
            style: theme.textTheme.bodyLarge?.copyWith(color: _ink),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _load,
            child: const Text('Tentar de novo'),
          ),
        ],
      );
    }

    return SelectableText(
      _markdown ?? '',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: _ink,
        height: 1.5,
      ),
    );
  }

  BoxDecoration _brutalBox(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _ink, width: 3),
      boxShadow: const [BoxShadow(color: _ink, offset: Offset(8, 8))],
    );
  }
}
