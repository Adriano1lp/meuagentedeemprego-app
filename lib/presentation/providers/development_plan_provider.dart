import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/development_plan_model.dart';
import '../../data/repositories/development_plan_repository_impl.dart';
import 'session_provider.dart';

final developmentPlanRepositoryProvider =
    Provider<DevelopmentPlanRepository>((ref) {
      return DevelopmentPlanRepositoryImpl();
    });

final developmentPlanProvider =
    StateNotifierProvider<DevelopmentPlanNotifier, DevelopmentPlanState>((ref) {
      final repository = ref.watch(developmentPlanRepositoryProvider);
      final session = ref.watch(sessionProvider);
      return DevelopmentPlanNotifier(repository, session.authToken);
    });

class DevelopmentPlanState {
  final DevelopmentPlanModel? plan;
  final bool isLoading;
  final bool isGenerating;
  final String? errorMessage;

  const DevelopmentPlanState({
    this.plan,
    this.isLoading = false,
    this.isGenerating = false,
    this.errorMessage,
  });

  bool get hasPlan => plan != null;

  DevelopmentPlanState copyWith({
    DevelopmentPlanModel? plan,
    bool? isLoading,
    bool? isGenerating,
    String? errorMessage,
    bool clearPlan = false,
    bool clearError = false,
  }) {
    return DevelopmentPlanState(
      plan: clearPlan ? null : (plan ?? this.plan),
      isLoading: isLoading ?? this.isLoading,
      isGenerating: isGenerating ?? this.isGenerating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class DevelopmentPlanNotifier extends StateNotifier<DevelopmentPlanState> {
  DevelopmentPlanNotifier(this._repository, this._authToken)
    : super(const DevelopmentPlanState());

  final DevelopmentPlanRepository _repository;
  final String? _authToken;

  Future<void> loadActivePlan() async {
    final authToken = _requireToken();
    if (authToken == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final plan = await _repository.getActivePlan(authToken: authToken);
      state = state.copyWith(
        plan: plan,
        clearPlan: plan == null,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanError(error),
      );
    }
  }

  Future<bool> generatePlan({bool replaceActive = false}) async {
    final authToken = _requireToken();
    if (authToken == null) return false;
    if (state.isGenerating) return false;

    state = state.copyWith(isGenerating: true, clearError: true);
    try {
      final plan = await _repository.generatePlan(
        authToken: authToken,
        replaceActive: replaceActive,
      );
      state = state.copyWith(
        plan: plan,
        isGenerating: false,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isGenerating: false,
        errorMessage: _cleanError(error),
      );
      return false;
    }
  }

  Future<bool> updateItemStatus({
    required String pdiId,
    required String itemId,
    required String status,
  }) async {
    final authToken = _requireToken();
    if (authToken == null) return false;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final plan = await _repository.updateItemStatus(
        authToken: authToken,
        pdiId: pdiId,
        itemId: itemId,
        status: status,
      );
      state = state.copyWith(
        plan: plan,
        isLoading: false,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _cleanError(error),
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  String? _requireToken() {
    final token = _authToken;
    if (token == null || token.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'Sessao expirada. Entre novamente.');
      return null;
    }
    return token;
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }
}
