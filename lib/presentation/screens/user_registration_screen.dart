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

  final TextEditingController _nameController = TextEditingController();
  final UserRepositoryImpl _repository = UserRepositoryImpl();

  PlatformFile? _selectedFile;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final currentUserId = ref.read(sessionProvider).userId;
    if (currentUserId != null) {
      _nameController.text = currentUserId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'pdf'],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _selectedFile = result.files.single;
    });
  }

  Future<void> _submit() async {
    final rawName = _nameController.text.trim();
    final file = _selectedFile;

    if (rawName.isEmpty) {
      _showMessage('Informe o nome do usuario.');
      return;
    }

    if (file == null || file.path == null) {
      _showMessage('Selecione um arquivo .txt ou .pdf.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final userId = SessionNotifier.normalizeUserId(rawName);

      await _repository.uploadCv(
        userId: userId,
        filePath: file.path!,
        fileName: file.name,
      );
      await _repository.rebuildEmbeddings(userId: userId);

      await ref.read(sessionProvider.notifier).setUserId(userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Upload concluido e curriculo processado com sucesso.',
            ),
          ),
        );

      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const ChatScreen()));
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
      appBar: AppBar(title: const Text('Cadastro')),
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
                        'Conectado com a API',
                        style: theme.textTheme.bodySmall?.copyWith(color: _ink),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Cadastre o usuario e envie o curriculo',
                      style: theme.textTheme.displayMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'O nome do usuario deve ser unico e sera utilizado para identificar seu curriculo. O arquivo do curriculo deve estar em formato .txt ou .pdf e conter as informacoes de experiencia, formacao academica e idiomas seguindo o padrao definido, se desejar adiconar alguma ferramenta especifica da sua profissa descreva tambem. Essas informacoes sera usada no embedding do seu usuario.',
                      style: theme.textTheme.bodyLarge,
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
                    Text('Nome do usuario', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Ex: adriano_silva',
                      ),
                    ),
                    const SizedBox(height: 18),
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _ink,
                                  ),
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          _isSubmitting
                              ? 'Enviando e processando...'
                              : 'Enviar cadastro',
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
