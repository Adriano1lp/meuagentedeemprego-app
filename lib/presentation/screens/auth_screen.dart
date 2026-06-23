import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/biometrics/biometric_login_coordinator.dart';
import '../../domain/terms/usage_terms.dart';
import '../providers/biometric_providers.dart';
import '../providers/session_provider.dart';
import 'home_screen.dart';
import 'terms_acceptance_screen.dart';
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
  bool _isBiometricChecking = true;
  bool _isBiometricSubmitting = false;
  bool _canUseBiometricLogin = false;
  bool _acceptedTerms = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBiometricLoginState();
    });
  }

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
    if (!_acceptedTerms) {
      _showMessage('Leia e aceite o termo de uso para criar sua conta.');
      return;
    }

    await _authenticate(
      action: () => _repository.register(
        displayName: displayName,
        email: email,
        password: password,
        termsAccepted: _acceptedTerms,
      ),
      offerBiometrics: false,
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
      offerBiometrics: true,
    );
  }

  Future<void> _authenticate({
    required Future<AuthSessionData> Function() action,
    required bool offerBiometrics,
  }) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final sessionData = await action();
      if (!sessionData.termsAccepted) {
        await ref.read(sessionProvider.notifier).saveSession(
          authToken: sessionData.authToken,
          userId: sessionData.userId,
          email: sessionData.email,
          displayName: sessionData.displayName,
          hasCv: false,
          termsAccepted: false,
        );

        if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TermsAcceptanceScreen()),
        );
        return;
      }

      final status = await _repository.getUserStatus(sessionData.authToken);
      await ref.read(sessionProvider.notifier).saveSession(
        authToken: sessionData.authToken,
        userId: sessionData.userId,
        email: sessionData.email,
        displayName: sessionData.displayName,
        hasCv: status.hasCv && status.hasEmbeddings,
        termsAccepted: sessionData.termsAccepted,
      );

      if (!mounted) return;

      if (offerBiometrics) {
        await _offerBiometricEnrollment(sessionData.userId);
      }
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

  Future<void> _loadBiometricLoginState() async {
    final userId = ref.read(sessionProvider).userId;
    if (userId == null || userId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _isBiometricChecking = false;
          _canUseBiometricLogin = false;
        });
      }
      return;
    }

    final canUse = await ref
        .read(biometricLoginCoordinatorProvider)
        .canUseBiometricLogin(userId);

    if (!mounted) return;
    setState(() {
      _isBiometricChecking = false;
      _canUseBiometricLogin = canUse;
    });
  }

  Future<void> _offerBiometricEnrollment(String userId) async {
    final coordinator = ref.read(biometricLoginCoordinatorProvider);
    final shouldPrompt = await coordinator.shouldPromptAfterPasswordLogin(
      userId,
    );
    if (!shouldPrompt || !context.mounted) {
      return;
    }

    final accepted = await _showBiometricEnrollmentDialog();

    final preferences = ref.read(biometricPreferenceStoreProvider);
    if (accepted == true) {
      await preferences.enableForUser(userId);
      if (mounted) {
        _showMessage('Biometria ativada com sucesso.');
      }
      return;
    }

    await preferences.declineForUser(userId);
    if (mounted) {
      _showMessage('Tudo bem. Voce pode entrar com email e senha.');
    }
  }

  Future<bool?> _showBiometricEnrollmentDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Usar biometria?'),
          content: const Text(
            'Seu dispositivo permite entrar com biometria. Deseja ativar para os proximos acessos?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Agora nao'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.fingerprint_rounded),
              label: const Text('Ativar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loginWithBiometrics() async {
    setState(() {
      _isBiometricSubmitting = true;
    });

    try {
      final coordinator = ref.read(biometricLoginCoordinatorProvider);
      final result = await coordinator.unlock(
        reason: 'Use sua biometria para entrar no Agente de Emprego.',
      );

      if (!mounted) return;
      switch (result) {
        case BiometricUnlockResult.unavailable:
          _showMessage('Biometria indisponivel neste dispositivo.');
          return;
        case BiometricUnlockResult.cancelled:
          _showMessage('Biometria cancelada. Entre com email e senha.');
          return;
        case BiometricUnlockResult.missingToken:
          _showMessage('Sessao expirada. Entre com email e senha.');
          return;
        case BiometricUnlockResult.success:
          break;
      }

      final authToken = await ref.read(sessionTokenStoreProvider).readToken();
      if (authToken == null || authToken.trim().isEmpty) {
        _showMessage('Sessao expirada. Entre com email e senha.');
        return;
      }

      final currentUser = await _repository.getCurrentUser(authToken);
      final status = currentUser.termsAccepted
          ? await _repository.getUserStatus(authToken)
          : const UserStatusData(hasCv: false, hasEmbeddings: false);

      await ref.read(sessionProvider.notifier).saveSession(
        authToken: authToken,
        userId: currentUser.userId,
        email: currentUser.email,
        displayName: currentUser.displayName,
        hasCv: status.hasCv && status.hasEmbeddings,
        termsAccepted: currentUser.termsAccepted,
      );

      if (!mounted) return;
      final nextScreen = !currentUser.termsAccepted
          ? const TermsAcceptanceScreen()
          : (status.hasCv && status.hasEmbeddings)
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
          _isBiometricSubmitting = false;
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
              if (!_isBiometricChecking && _canUseBiometricLogin) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: (_isSubmitting || _isBiometricSubmitting)
                        ? null
                        : _loginWithBiometrics,
                    style: OutlinedButton.styleFrom(backgroundColor: _paper),
                    icon: _isBiometricSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(_ink),
                            ),
                          )
                        : const Icon(Icons.fingerprint_rounded),
                    label: Text(
                      _isBiometricSubmitting
                          ? 'Validando biometria...'
                          : 'Entrar com biometria',
                    ),
                  ),
                ),
              ],
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
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: _chipBox(_paper),
                child: Text(
                  usageTermsText,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                value: _acceptedTerms,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _acceptedTerms = value == true;
                        });
                      },
                title: const Text('Li e concordo com o termo de uso'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _register,
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
