import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/chat_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../providers/session_provider.dart';
import 'chat_screen.dart';

class UserRegistrationScreen extends ConsumerStatefulWidget {
  const UserRegistrationScreen({super.key});

  @override
  ConsumerState<UserRegistrationScreen> createState() =>
      _UserRegistrationScreenState();
}

class _UserRegistrationScreenState
    extends ConsumerState<UserRegistrationScreen> {
  static const Color _ink = Color(0xFF111111);
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _yellow = Color(0xFFFFE16A);
  static const Color _blue = Color(0xFF87D2FF);
  static const Color _green = Color(0xFFB6F36A);

  final UserRepositoryImpl _repository = UserRepositoryImpl();

  PlatformFile? _selectedFile;
  bool _isSubmitting = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _selectedFile = result.files.single;
    });
  }

  Future<void> _submit() async {
    final file = _selectedFile;
    final session = ref.read(sessionProvider);

    if (session.authToken == null || session.authToken!.trim().isEmpty) {
      _showMessage('Sessao expirada. Entre novamente.');
      return;
    }

    if (file == null) {
      _showMessage('Selecione um arquivo .txt ou .pdf.');
      return;
    }

    if (file.path == null && file.bytes == null) {
      _showMessage('Nao foi possivel ler o arquivo selecionado.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _repository.uploadCv(
        authToken: session.authToken!,
        fileName: file.name,
        filePath: file.path,
        fileBytes: file.bytes,
      );
      await _repository.rebuildEmbeddings(authToken: session.authToken!);

      await ref.read(sessionProvider.notifier).updateHasCv(true);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Curriculo enviado e processado com sucesso.',
            ),
          ),
        );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
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
    final session = ref.watch(sessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar curriculo')),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: _chipBox(_paper),
                      child: Text(
                        'Conta autenticada',
                        style: theme.textTheme.bodySmall?.copyWith(color: _ink),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Finalize sua conta com o curriculo',
                      style: theme.textTheme.displayMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Depois do upload em ${ChatRepositoryImpl.apiBaseUrl}/users/me/upload-cv, o app executa /users/me/rebuild-embeddings para deixar sua analise pronta em qualquer dispositivo.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Conta: ${session.displayName ?? session.userId ?? 'Usuario'}',
                      style: theme.textTheme.titleMedium?.copyWith(color: _ink),
                    ),
                    if (session.email != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        session.email!,
                        style: theme.textTheme.bodyMedium?.copyWith(color: _ink),
                      ),
                    ],
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
                      'Arquivo do curriculo',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: _brutalBox(_blue, radius: 18, offset: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFile?.name ??
                                'Nenhum arquivo selecionado ainda.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Formatos aceitos: .txt e .pdf',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF303744),
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _isSubmitting ? null : _pickFile,
                            icon: const Icon(Icons.attach_file),
                            label: const Text('Escolher arquivo'),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: _paper,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(backgroundColor: _green),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(_ink),
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          _isSubmitting
                              ? 'Enviando e processando...'
                              : 'Enviar curriculo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _brutalBox(
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

  BoxDecoration _chipBox(Color color) {
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
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
