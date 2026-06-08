import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/terms/usage_terms.dart';
import '../providers/session_provider.dart';
import 'home_screen.dart';
import 'user_registration_screen.dart';

class TermsAcceptanceScreen extends ConsumerStatefulWidget {
  const TermsAcceptanceScreen({super.key});

  @override
  ConsumerState<TermsAcceptanceScreen> createState() =>
      _TermsAcceptanceScreenState();
}

class _TermsAcceptanceScreenState extends ConsumerState<TermsAcceptanceScreen> {
  final AuthRepositoryImpl _repository = AuthRepositoryImpl();

  bool _accepted = false;
  bool _isSubmitting = false;

  Future<void> _acceptTerms() async {
    final session = ref.read(sessionProvider);
    final authToken = session.authToken;
    if (authToken == null || authToken.trim().isEmpty) {
      _showMessage('Entre na conta novamente para aceitar o termo.');
      return;
    }
    if (!_accepted) {
      _showMessage('Leia e aceite o termo de uso para continuar.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final currentUser = await _repository.acceptTerms(authToken);
      final status = await _repository.getUserStatus(authToken);
      await ref.read(sessionProvider.notifier).saveSession(
        authToken: authToken,
        userId: currentUser.userId,
        email: currentUser.email,
        displayName: currentUser.displayName,
        hasCv: status.hasCv && status.hasEmbeddings,
        termsAccepted: currentUser.termsAccepted,
      );

      if (!mounted) return;

      final nextScreen = (status.hasCv && status.hasEmbeddings)
          ? const HomeScreen()
          : const UserRegistrationScreen();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(usageTermsTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Antes de continuar', style: theme.textTheme.displayMedium),
            const SizedBox(height: 12),
            Text(usageTermsText, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 18),
            CheckboxListTile(
              value: _accepted,
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      setState(() {
                        _accepted = value == true;
                      });
                    },
              title: const Text('Li e concordo com o termo de uso'),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSubmitting ? null : _acceptTerms,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSubmitting ? 'Salvando...' : 'Aceitar termo'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
