import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cover_letter_gate.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_provider.dart';
import '../providers/consent_provider.dart';
import '../providers/cover_letter_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/app_drawer.dart';
import '../widgets/chat_bubble.dart';
import 'user_registration_screen.dart';

class CoverLetterScreen extends ConsumerStatefulWidget {
  const CoverLetterScreen({super.key});

  @override
  ConsumerState<CoverLetterScreen> createState() => _CoverLetterScreenState();
}

class _CoverLetterScreenState extends ConsumerState<CoverLetterScreen> {
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _ink = Color(0xFF111111);
  static const Color _canvas = Color(0xFFFFF6E9);
  static const Color _pink = Color(0xFFFF5D8F);
  static const Color _yellow = Color(0xFFFFE16A);

  final TextEditingController _companyController = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isCheckingStatus = true;
  bool _canGenerate = false;
  bool _statusFailed = false;
  bool _handleInFlight = false;
  String? _blockMessage = CoverLetterGate.waitingStatusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshReadiness();
    });
  }

  @override
  void dispose() {
    _companyController.dispose();
    super.dispose();
  }

  bool get _generateEnabled =>
      _canGenerate && !_isLoading && !_isCheckingStatus;

  /// GET /users/me/status via the same fetcher as Analisar vaga.
  /// Returns false when embeddings are missing or the status call fails.
  Future<bool> _refreshReadiness() async {
    if (!mounted) return false;
    setState(() {
      _isCheckingStatus = true;
    });

    try {
      final status = await ref.read(userStatusFetcherProvider)();
      if (!mounted) return false;
      final allowed = CoverLetterGate.canGenerate(status);
      setState(() {
        _isCheckingStatus = false;
        _canGenerate = allowed;
        _statusFailed = false;
        _blockMessage = CoverLetterGate.blockMessage(status);
      });
      return allowed;
    } catch (e) {
      if (!mounted) return false;
      ref.read(consentProvider.notifier).applyIfOutdated(e);
      final detail = _visibleError(e).trim();
      setState(() {
        _isCheckingStatus = false;
        _canGenerate = false;
        _statusFailed = true;
        _blockMessage = detail.isEmpty
            ? CoverLetterGate.statusErrorMessage
            : '${CoverLetterGate.statusErrorMessage} $detail';
      });
      return false;
    }
  }

  Future<void> _openCvUpload() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const UserRegistrationScreen(),
      ),
    );
    if (!mounted) return;
    await _refreshReadiness();
  }

  Future<void> _handleGenerate() async {
    if (_handleInFlight || _isLoading || _isCheckingStatus || !_canGenerate) {
      return;
    }
    _handleInFlight = true;

    try {
      final companyName = _companyController.text.trim();
      if (companyName.isEmpty) {
        _showMessage('Informe o nome da empresa.');
        return;
      }

      final authToken = await ref
          .read(sessionProvider.notifier)
          .readAccessToken();
      if (!mounted) return;
      if (authToken == null || authToken.trim().isEmpty) {
        _showMessage('Sessao expirada. Entre novamente.');
        return;
      }

      final ready = await _refreshReadiness();
      if (!ready || !mounted) return;

      final userMessage = ChatMessage(
        id: 'u-${DateTime.now().microsecondsSinceEpoch}',
        text: companyName,
        isUser: true,
        timestamp: DateTime.now(),
      );

      setState(() {
        _messages.add(userMessage);
        _isLoading = true;
      });

      try {
        final response = await ref.read(generateCoverLetterProvider)(
          companyName: companyName,
          authToken: authToken,
        );

        if (!mounted) return;
        setState(() {
          _messages.add(response);
          _companyController.clear();
        });
      } catch (e) {
        if (!mounted) return;
        ref.read(consentProvider.notifier).applyIfOutdated(e);
        _showMessage(_visibleError(e));
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } finally {
      _handleInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Carta de apresentacao', style: theme.textTheme.titleLarge),
            Text(
              _isLoading
                  ? 'Processando /users/me/cover-letter'
                  : 'Informe a empresa e gere um PDF autenticado',
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF4E5566),
              ),
            ),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(color: _canvas),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: _messages.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            return ChatBubble(message: _messages[index]);
                          },
                        ),
                ),
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: _brutalBoxDecoration(_yellow),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: _pillDecoration(_paper),
                  child: Text(
                    'Endpoint /users/me/cover-letter',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _ink,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Gere uma carta em PDF',
                  style: theme.textTheme.displayMedium?.copyWith(color: _ink),
                ),
                const SizedBox(height: 14),
                Text(
                  'Digite o nome da empresa para criar uma carta de apresentacao usando o contexto do seu curriculo.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: _ink),
                ),
                const SizedBox(height: 22),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _HeroTag(label: 'Carta personalizada'),
                    _HeroTag(label: 'PDF para download'),
                    _HeroTag(label: 'Contexto do curriculo'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final generateEnabled = _generateEnabled;
    final showGate =
        !_isCheckingStatus && !_canGenerate && _blockMessage != null;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showGate) ...[
              _buildGate(_blockMessage!, statusFailed: _statusFailed),
              const SizedBox(height: 10),
            ],
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                _inputHint(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF4E5566),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              decoration: _brutalBoxDecoration(_paper, radius: 18, offset: 6),
              child: TextField(
                controller: _companyController,
                enabled: generateEnabled,
                decoration: const InputDecoration(
                  hintText: 'Nome da empresa...',
                  border: InputBorder.none,
                ),
                onSubmitted: generateEnabled ? (_) => _handleGenerate() : null,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: generateEnabled ? _pink : _yellow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _ink, width: 3),
                boxShadow: const [
                  BoxShadow(color: _ink, offset: Offset(4, 4)),
                ],
              ),
              child: FilledButton.icon(
                onPressed: generateEnabled ? _handleGenerate : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: _ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide.none,
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_ink),
                        ),
                      )
                    : const Icon(Icons.mark_email_read_outlined),
                label: Text(
                  _isLoading
                      ? 'Gerando'
                      : _isCheckingStatus
                          ? 'Verificando'
                          : 'Gerar carta',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _inputHint() {
    if (_isLoading) {
      return 'A API esta gerando a carta e preparando o PDF.';
    }
    if (_isCheckingStatus) {
      return 'Verificando curriculo e embeddings...';
    }
    if (_canGenerate) {
      return 'Informe a empresa e toque em gerar carta.';
    }
    return _blockMessage ?? CoverLetterGate.waitingStatusMessage;
  }

  Widget _buildGate(String message, {required bool statusFailed}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: _brutalBoxDecoration(_yellow, radius: 18, offset: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _ink,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: statusFailed
                  ? () async {
                      await _refreshReadiness();
                    }
                  : () async {
                      await _openCvUpload();
                    },
              icon: Icon(
                statusFailed ? Icons.refresh : Icons.badge_outlined,
              ),
              label: Text(
                statusFailed
                    ? 'Tentar novamente'
                    : 'Enviar ou atualizar curriculo',
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _brutalBoxDecoration(
    Color color, {
    double radius = 24,
    double offset = 8,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _ink, width: 3),
      boxShadow: [BoxShadow(color: _ink, offset: Offset(offset, offset))],
    );
  }

  BoxDecoration _pillDecoration(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _ink, width: 2),
      boxShadow: const [BoxShadow(color: _ink, offset: Offset(3, 3))],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
        ),
      );
  }

  String _visibleError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}

class _HeroTag extends StatelessWidget {
  final String label;

  const _HeroTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDF7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF111111), width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF111111), offset: Offset(3, 3)),
        ],
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF111111),
        ),
      ),
    );
  }
}
