import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/consent_outdated.dart';
import '../../data/legal_versions.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../providers/consent_provider.dart';
import '../providers/session_provider.dart';
import '../widgets/legal_accept_checkbox.dart';
import 'home_screen.dart';
import 'user_registration_screen.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _yellow = Color(0xFFFFE16A);
  static const Color _blue = Color(0xFF87D2FF);
  static const Color _green = Color(0xFFB6F36A);

  final AuthRepositoryImpl _repository = AuthRepositoryImpl();
  final TextEditingController _registerNameController = TextEditingController();
  final TextEditingController _registerEmailController = TextEditingController();
  final TextEditingController _registerPasswordController =
      TextEditingController();
  final TextEditingController _loginEmailController = TextEditingController();
  final TextEditingController _loginPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;

  bool get _canCreateAccount => _termsAccepted && _privacyAccepted;

  @override
  void dispose() {
    _registerNameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final displayName = _registerNameController.text.trim();
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;

    if (displayName.isEmpty || email.isEmpty || password.isEmpty) {
      _showMessage('Preencha nome, email e senha.');
      return;
    }

    if (!_termsAccepted || !_privacyAccepted) {
      _showMessage(
        'Aceite os Termos de uso e a Politica de privacidade para criar a conta.',
      );
      return;
    }

    await _authenticate(
      action: () => _repository.register(
        displayName: displayName,
        email: email,
        password: password,
        termsAccepted: true,
        privacyAccepted: true,
      ),
    );
  }

  Future<void> _login() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage('Preencha email e senha.');
      return;
    }

    await _authenticate(
      action: () => _repository.login(
        email: email,
        password: password,
      ),
    );
  }

  Future<void> _authenticate({
    required Future<AuthSessionData> Function() action,
  }) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final sessionData = await action();
      ref.read(consentProvider.notifier).applyFromUser(
        termsVersion: sessionData.termsVersion,
        privacyVersion: sessionData.privacyVersion,
      );

      var hasCv = false;
      try {
        final status = await _repository.getUserStatus(sessionData.authToken);
        hasCv = status.hasCv && status.hasEmbeddings;
      } on ConsentOutdatedException catch (error) {
        ref.read(consentProvider.notifier).applyException(error);
      }

      await ref.read(sessionProvider.notifier).saveSession(
        authToken: sessionData.authToken,
        userId: sessionData.userId,
        email: sessionData.email,
        displayName: sessionData.displayName,
        hasCv: hasCv,
      );

      if (!mounted) return;
      if (ref.read(consentProvider).blocksApp) {
        return;
      }

      final nextScreen = hasCv
          ? const HomeScreen()
          : const UserRegistrationScreen();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => nextScreen),
      );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Entrar na conta'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Entrar'),
              Tab(text: 'Criar conta'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLoginTab(theme),
            _buildRegisterTab(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginTab(ThemeData theme) {
    return SingleChildScrollView(
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: _chipBox(_paper),
                  child: Text(
                    'Recuperacao entre dispositivos',
                    style: theme.textTheme.bodySmall?.copyWith(color: _ink),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Entre para recuperar sua conta',
                  style: theme.textTheme.displayMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ao entrar, o app consulta seu status na API e restaura o acesso ao curriculo, embeddings e PDFs do usuario autenticado.',
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _buildFormCard(
            theme: theme,
            color: _blue,
            title: 'Acessar conta existente',
            children: [
              TextField(
                controller: _loginEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _loginPasswordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Senha'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _login,
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  icon: _buildLoadingIcon(),
                  label: Text(_isSubmitting ? 'Entrando...' : 'Entrar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFormCard(
            theme: theme,
            color: _yellow,
            title: 'Criar conta nova',
            children: [
              TextField(
                controller: _registerNameController,
                decoration: const InputDecoration(hintText: 'Nome'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _registerEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _registerPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Senha com pelo menos 8 caracteres',
                ),
              ),
              const SizedBox(height: 12),
              LegalAcceptCheckbox(
                doc: LegalDoc.terms,
                value: _termsAccepted,
                onChanged: (value) {
                  setState(() {
                    _termsAccepted = value;
                  });
                },
                enabled: !_isSubmitting,
              ),
              LegalAcceptCheckbox(
                doc: LegalDoc.privacy,
                value: _privacyAccepted,
                onChanged: (value) {
                  setState(() {
                    _privacyAccepted = value;
                  });
                },
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('createAccountButton'),
                  onPressed: _isSubmitting || !_canCreateAccount
                      ? null
                      : _register,
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  icon: _buildLoadingIcon(),
                  label: Text(_isSubmitting ? 'Criando...' : 'Criar conta'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({
    required ThemeData theme,
    required Color color,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _brutalBox(color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLoadingIcon() {
    if (!_isSubmitting) {
      return const Icon(Icons.login_rounded);
    }

    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(_ink),
      ),
    );
  }

  BoxDecoration _brutalBox(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _ink, width: 3),
      boxShadow: const [
        BoxShadow(color: _ink, offset: Offset(8, 8)),
      ],
    );
  }

  BoxDecoration _chipBox(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _ink, width: 2),
      boxShadow: const [
        BoxShadow(color: _ink, offset: Offset(3, 3)),
      ],
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
