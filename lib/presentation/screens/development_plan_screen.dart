import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/development_plan_model.dart';
import '../providers/development_plan_provider.dart';
import '../widgets/app_drawer.dart';

class DevelopmentPlanScreen extends ConsumerStatefulWidget {
  const DevelopmentPlanScreen({super.key});

  @override
  ConsumerState<DevelopmentPlanScreen> createState() =>
      _DevelopmentPlanScreenState();
}

class _DevelopmentPlanScreenState extends ConsumerState<DevelopmentPlanScreen> {
  static const Color _paper = Color(0xFFFDFDF7);
  static const Color _ink = Color(0xFF111111);
  static const Color _canvas = Color(0xFFFFF6E9);
  static const Color _pink = Color(0xFFFF5D8F);
  static const Color _yellow = Color(0xFFFFE16A);
  static const Color _green = Color(0xFFB6F36A);
  static const Color _blue = Color(0xFF87D2FF);

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(developmentPlanProvider.notifier).loadActivePlan(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(developmentPlanProvider);
    ref.listen(developmentPlanProvider, (previous, next) {
      final error = next.errorMessage;
      if (error != null && error != previous?.errorMessage) {
        _showMessage(error);
      }
    });

    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PDI', style: Theme.of(context).textTheme.titleLarge),
            Text(
              state.isLoading
                  ? 'Carregando plano ativo'
                  : 'Plano de desenvolvimento com checklist',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF4E5566),
              ),
            ),
          ],
        ),
      ),
      drawer: const AppDrawer(),
      body: DecoratedBox(
        decoration: const BoxDecoration(color: _canvas),
        child: SafeArea(
          top: false,
          child: state.isLoading && !state.hasPlan
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(developmentPlanProvider.notifier).loadActivePlan(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                    children: [
                      if (state.plan == null)
                        _EmptyPlanCard(
                          isGenerating: state.isGenerating,
                          onGenerate: () => _handleGenerate(replace: false),
                        )
                      else
                        _PlanContent(
                          plan: state.plan!,
                          isBusy: state.isLoading || state.isGenerating,
                          onGenerate: () => _confirmReplace(),
                          onStatusChanged: _handleStatusChanged,
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _handleGenerate({required bool replace}) async {
    final ok = await ref
        .read(developmentPlanProvider.notifier)
        .generatePlan(replaceActive: replace);
    if (ok && mounted) {
      _showMessage(replace ? 'PDI atualizado.' : 'PDI gerado.');
    }
  }

  Future<void> _confirmReplace() async {
    final shouldReplace = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Substituir PDI ativo?'),
          content: const Text(
            'Gerar um novo PDI arquiva o plano ativo e cria um plano atualizado com base no historico recente.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Substituir'),
            ),
          ],
        );
      },
    );

    if (shouldReplace == true) {
      await _handleGenerate(replace: true);
    }
  }

  Future<void> _handleStatusChanged(
    DevelopmentPlanItemModel item,
    String status,
  ) async {
    final plan = ref.read(developmentPlanProvider).plan;
    if (plan == null || item.status == status) return;

    await ref.read(developmentPlanProvider.notifier).updateItemStatus(
          pdiId: plan.pdiId,
          itemId: item.id,
          status: status,
        );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EmptyPlanCard extends StatelessWidget {
  final bool isGenerating;
  final VoidCallback onGenerate;

  const _EmptyPlanCard({
    required this.isGenerating,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: _box(_DevelopmentPlanScreenState._yellow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pill(label: '70 / 20 / 10'),
          const SizedBox(height: 18),
          Text(
            'Gere seu PDI',
            style: theme.textTheme.displayMedium?.copyWith(
              color: _DevelopmentPlanScreenState._ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Use o historico das ultimas vagas analisadas para criar um plano de desenvolvimento com acoes praticas, feedback e estudo formal.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: _DevelopmentPlanScreenState._ink,
            ),
          ),
          const SizedBox(height: 22),
          _BrutalButton(
            label: isGenerating ? 'Gerando PDI' : 'Gerar PDI',
            icon: isGenerating
                ? Icons.hourglass_top_rounded
                : Icons.auto_awesome_rounded,
            isBusy: isGenerating,
            onPressed: isGenerating ? null : onGenerate,
          ),
        ],
      ),
    );
  }
}

class _PlanContent extends StatelessWidget {
  final DevelopmentPlanModel plan;
  final bool isBusy;
  final VoidCallback onGenerate;
  final void Function(DevelopmentPlanItemModel item, String status)
      onStatusChanged;

  const _PlanContent({
    required this.plan,
    required this.isBusy,
    required this.onGenerate,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PlanHeader(plan: plan, isBusy: isBusy, onGenerate: onGenerate),
        const SizedBox(height: 18),
        _ContextBlock(plan: plan),
        const SizedBox(height: 18),
        _SectionBlock(
          title: '70% pratica',
          subtitle: 'Experiencia aplicada',
          color: _DevelopmentPlanScreenState._green,
          items: plan.sections['70'] ?? const [],
          onStatusChanged: onStatusChanged,
        ),
        const SizedBox(height: 14),
        _SectionBlock(
          title: '20% mentoria',
          subtitle: 'Feedback, networking e revisao',
          color: _DevelopmentPlanScreenState._blue,
          items: plan.sections['20'] ?? const [],
          onStatusChanged: onStatusChanged,
        ),
        const SizedBox(height: 14),
        _SectionBlock(
          title: '10% estudo',
          subtitle: 'Conteudo estruturado',
          color: _DevelopmentPlanScreenState._yellow,
          items: plan.sections['10'] ?? const [],
          onStatusChanged: onStatusChanged,
        ),
      ],
    );
  }
}

class _PlanHeader extends StatelessWidget {
  final DevelopmentPlanModel plan;
  final bool isBusy;
  final VoidCallback onGenerate;

  const _PlanHeader({
    required this.plan,
    required this.isBusy,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final progress = plan.progressPercent.clamp(0, 100);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _box(_DevelopmentPlanScreenState._pink),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(plan.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text(plan.mainObjective, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 16,
                    value: progress / 100,
                    backgroundColor: _DevelopmentPlanScreenState._paper,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _DevelopmentPlanScreenState._green,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$progress%',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _BrutalButton(
            label: isBusy ? 'Aguarde' : 'Gerar PDI',
            icon: Icons.refresh_rounded,
            isBusy: isBusy,
            onPressed: isBusy ? null : onGenerate,
          ),
        ],
      ),
    );
  }
}

class _ContextBlock extends StatelessWidget {
  final DevelopmentPlanModel plan;

  const _ContextBlock({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _box(_DevelopmentPlanScreenState._paper, offset: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contexto', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(plan.summary),
          const SizedBox(height: 14),
          _ChipWrap(title: 'Gaps', values: plan.priorityGaps),
          const SizedBox(height: 12),
          _ChipWrap(title: 'Forcas', values: plan.strengthsToLeverage),
        ],
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<DevelopmentPlanItemModel> items;
  final void Function(DevelopmentPlanItemModel item, String status)
      onStatusChanged;

  const _SectionBlock({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.items,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _box(color, offset: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          for (final item in items) ...[
            _ChecklistItem(item: item, onStatusChanged: onStatusChanged),
            if (item != items.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final DevelopmentPlanItemModel item;
  final void Function(DevelopmentPlanItemModel item, String status)
      onStatusChanged;

  const _ChecklistItem({
    required this.item,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _box(_DevelopmentPlanScreenState._paper, radius: 16, offset: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(item.description),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: item.gap),
              _Pill(label: 'prioridade ${_priorityLabel(item.priority)}'),
              _Pill(label: 'peso ${item.weight}'),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Pendente')),
              ButtonSegment(value: 'in_progress', label: Text('Andamento')),
              ButtonSegment(value: 'completed', label: Text('Concluido')),
            ],
            selected: {item.status},
            onSelectionChanged: (value) {
              onStatusChanged(item, value.first);
            },
          ),
        ],
      ),
    );
  }

  String _priorityLabel(String value) {
    return switch (value) {
      'high' => 'alta',
      'low' => 'baixa',
      _ => 'media',
    };
  }
}

class _ChipWrap extends StatelessWidget {
  final String title;
  final List<String> values;

  const _ChipWrap({required this.title, required this.values});

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values.map((value) => _Pill(label: value)).toList(),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _DevelopmentPlanScreenState._paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _DevelopmentPlanScreenState._ink, width: 2),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _BrutalButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isBusy;
  final VoidCallback? onPressed;

  const _BrutalButton({
    required this.label,
    required this.icon,
    required this.isBusy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: isBusy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );
  }
}

BoxDecoration _box(Color color, {double radius = 22, double offset = 7}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _DevelopmentPlanScreenState._ink, width: 3),
    boxShadow: [
      BoxShadow(
        color: _DevelopmentPlanScreenState._ink,
        offset: Offset(offset, offset),
      ),
    ],
  );
}
