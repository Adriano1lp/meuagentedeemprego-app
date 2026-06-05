import 'package:flutter_test/flutter_test.dart';
import 'package:meu_agente_de_emprego/data/models/development_plan_model.dart';
import 'package:meu_agente_de_emprego/data/repositories/development_plan_repository_impl.dart';
import 'package:meu_agente_de_emprego/presentation/providers/development_plan_provider.dart';

void main() {
  test('carrega estado vazio quando nao existe PDI ativo', () async {
    final repository = _FakeDevelopmentPlanRepository(activePlan: null);
    final notifier = DevelopmentPlanNotifier(repository, 'token');

    await notifier.loadActivePlan();

    expect(notifier.state.plan, isNull);
    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.errorMessage, isNull);
  });

  test('gera PDI com sucesso', () async {
    final generatedPlan = _plan(progressPercent: 0);
    final repository = _FakeDevelopmentPlanRepository(generatedPlan: generatedPlan);
    final notifier = DevelopmentPlanNotifier(repository, 'token');

    final ok = await notifier.generatePlan();

    expect(ok, isTrue);
    expect(notifier.state.plan?.title, 'PDI de teste');
    expect(notifier.state.plan?.progressPercent, 0);
    expect(notifier.state.isGenerating, isFalse);
  });

  test('atualiza status e progresso do PDI', () async {
    final updatedPlan = _plan(
      progressPercent: 60,
      itemStatus: 'completed',
    );
    final repository = _FakeDevelopmentPlanRepository(updatedPlan: updatedPlan);
    final notifier = DevelopmentPlanNotifier(repository, 'token');

    final ok = await notifier.updateItemStatus(
      pdiId: 'pdi_1',
      itemId: 'item_1',
      status: 'completed',
    );

    expect(ok, isTrue);
    expect(notifier.state.plan?.progressPercent, 60);
    expect(notifier.state.plan?.sections['70']?.first.status, 'completed');
  });
}

class _FakeDevelopmentPlanRepository implements DevelopmentPlanRepository {
  final DevelopmentPlanModel? activePlan;
  final DevelopmentPlanModel? generatedPlan;
  final DevelopmentPlanModel? updatedPlan;

  _FakeDevelopmentPlanRepository({
    this.activePlan,
    this.generatedPlan,
    this.updatedPlan,
  });

  @override
  Future<DevelopmentPlanModel?> getActivePlan({
    required String authToken,
  }) async {
    return activePlan;
  }

  @override
  Future<DevelopmentPlanModel> generatePlan({
    required String authToken,
    int limit = 10,
    bool replaceActive = false,
  }) async {
    return generatedPlan ?? _plan(progressPercent: 0);
  }

  @override
  Future<DevelopmentPlanModel> updateItemStatus({
    required String authToken,
    required String pdiId,
    required String itemId,
    required String status,
  }) async {
    return updatedPlan ?? _plan(progressPercent: 0);
  }
}

DevelopmentPlanModel _plan({
  required int progressPercent,
  String itemStatus = 'pending',
}) {
  final item = DevelopmentPlanItemModel(
    id: 'item_1',
    title: 'Criar dashboard',
    description: 'Publicar uma entrega pratica.',
    category: '70',
    gap: 'Power BI',
    priority: 'high',
    status: itemStatus,
    weight: 3,
  );

  return DevelopmentPlanModel(
    pdiId: 'pdi_1',
    title: 'PDI de teste',
    mainObjective: 'Evoluir em Power BI.',
    summary: 'Plano de teste.',
    secondaryObjectives: const ['Praticar Power BI'],
    priorityAreas: const ['Dados'],
    priorityGaps: const ['Power BI'],
    strengthsToLeverage: const ['SQL'],
    progressPercent: progressPercent,
    status: 'active',
    sections: {
      '70': [item],
      '20': const [],
      '10': const [],
    },
    checklistItems: [item],
  );
}
