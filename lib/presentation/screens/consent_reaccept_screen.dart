import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/consent_outdated.dart';
import '../../data/legal_versions.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/legal_repository_impl.dart';
import '../app_navigator.dart';
import '../providers/consent_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/legal_document_panel.dart';
import 'auth_screen.dart';

class ConsentReacceptScreen extends ConsumerStatefulWidget {
  const ConsentReacceptScreen({super.key});

  @override
  ConsumerState<ConsentReacceptScreen> createState() =>
      _ConsentReacceptScreenState();
}

class _ConsentReacceptScreenState extends ConsumerState<ConsentReacceptScreen> {
  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _yellow = Color(0xFFFFE16A);
  static const Color _green = Color(0xFFB6F36A);

  final AuthRepositoryImpl _authRepository = AuthRepositoryImpl();

  final Map<LegalDoc, bool> _accepted = {
    LegalDoc.terms: false,
    LegalDoc.privacy: false,
  };
  final Map<LegalDoc, bool> _viewed = {
    LegalDoc.terms: false,
    LegalDoc.privacy: false,
  };

  bool _isSubmitting = false;

  Future<void> _submit() async {
    final authToken = await ref.read(sessionProvider.notifier).readAccessToken();
    final outdated = ref.read(consentProvider).outdatedDocs;

    if (authToken == null || authToken.trim().isEmpty) {
      _showMessage('Sessao expirada. Entre novamente.');
      return;
    }

    if (outdated.any((doc) => _accepted[doc] != true || _viewed[doc] != true)) {
      _showMessage('Leia e marque os documentos vigentes para continuar.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final legalRepository = ref.read(legalRepositoryProvider);
      for (final doc in outdated) {
        await legalRepository.acceptConsent(
          authToken: authToken,
          doc: doc,
          version: doc.currentVersion,
        );
      }

      try {
        final currentUser = await _authRepository.getCurrentUser(authToken);
        ref.read(consentProvider.notifier).applyFromUser(
          termsVersion: currentUser.termsVersion,
          privacyVersion: currentUser.privacyVersion,
        );
      } on ConsentOutdatedException catch (error) {
        ref.read(consentProvider.notifier).applyException(error);
        if (!mounted) return;
        _showMessage(error.message);
        return;
      }

      if (!mounted) return;
      if (ref.read(consentProvider).blocksApp) {
        _showMessage('Ainda ha documentos vigentes para aceitar.');
        return;
      }
      _showMessage('Aceite atualizado. Voce ja pode usar o app.');
    } catch (e) {
      if (!mounted) return;
      ref.read(consentProvider.notifier).applyIfOutdated(e);
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    await ref.read(sessionProvider.notifier).clear();
    ref.read(consentProvider.notifier).clear();
    if (!mounted) return;
    appNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final consent = ref.watch(consentProvider);
    final outdated = consent.outdatedDocs;
    final canSubmit =
        outdated.isNotEmpty &&
        outdated.every((doc) => _accepted[doc] == true && _viewed[doc] == true);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Atualizar aceites'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: _brutalBox(_yellow),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Documentos legais atualizados',
                        style: theme.textTheme.displayMedium,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Suas versoes aceitas nao sao as vigentes. Leia o texto carregado da API, marque os checkboxes e confirme. O app fica bloqueado ate o reaceite via POST /consent.',
                        style: theme.textTheme.bodyLarge?.copyWith(color: _ink),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: _brutalBox(_paper),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Versoes vigentes',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Termos $CURRENT_TERMS_VERSION e privacidade $CURRENT_PRIVACY_VERSION.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: _ink),
                      ),
                      const SizedBox(height: 12),
                      for (final doc in outdated)
                        LegalDocumentPanel(
                          doc: doc,
                          accepted: _accepted[doc] == true,
                          enabled: !_isSubmitting,
                          onLoaded: (viewed) {
                            setState(() {
                              _viewed[doc] = viewed;
                              if (!viewed) {
                                _accepted[doc] = false;
                              }
                            });
                          },
                          onAccepted: (value) {
                            setState(() {
                              _accepted[doc] = value;
                            });
                          },
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const ValueKey('reacceptConsentButton'),
                          onPressed: _isSubmitting || !canSubmit ? null : _submit,
                          style: FilledButton.styleFrom(backgroundColor: _green),
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _ink,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.verified_outlined),
                          label: Text(
                            _isSubmitting
                                ? 'Enviando aceites...'
                                : 'Aceitar e continuar',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting ? null : _logout,
                          icon: const Icon(Icons.logout_rounded),
                          label: const Text('Sair'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
