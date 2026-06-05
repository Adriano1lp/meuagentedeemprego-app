import 'package:dio/dio.dart';

import '../models/development_plan_model.dart';
import 'chat_repository_impl.dart';

abstract class DevelopmentPlanRepository {
  Future<DevelopmentPlanModel?> getActivePlan({required String authToken});

  Future<DevelopmentPlanModel> generatePlan({
    required String authToken,
    int limit = 10,
    bool replaceActive = false,
  });

  Future<DevelopmentPlanModel> updateItemStatus({
    required String authToken,
    required String pdiId,
    required String itemId,
    required String status,
  });
}

class DevelopmentPlanRepositoryImpl implements DevelopmentPlanRepository {
  DevelopmentPlanRepositoryImpl()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ChatRepositoryImpl.apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  final Dio _dio;

  @override
  Future<DevelopmentPlanModel?> getActivePlan({
    required String authToken,
  }) async {
    try {
      final response = await _dio.get(
        '/users/me/development-plan/active',
        options: Options(headers: _authHeaders(authToken)),
      );
      final data = _responseMap(response.data);
      if (data['exists'] != true || data['plan'] == null) {
        return null;
      }
      final plan = data['plan'];
      if (plan is! Map<String, dynamic>) {
        throw Exception('Resposta da API em formato invalido');
      }
      return DevelopmentPlanModel.fromJson(plan);
    } on DioException catch (error) {
      throw Exception(_extractErrorMessage(error));
    } catch (error) {
      throw Exception('Erro inesperado: $error');
    }
  }

  @override
  Future<DevelopmentPlanModel> generatePlan({
    required String authToken,
    int limit = 10,
    bool replaceActive = false,
  }) async {
    try {
      final response = await _dio.post(
        '/users/me/development-plan/generate',
        data: {'limit': limit, 'replace_active': replaceActive},
        options: Options(headers: _authHeaders(authToken)),
      );
      return DevelopmentPlanModel.fromJson(_responseMap(response.data));
    } on DioException catch (error) {
      throw Exception(_extractErrorMessage(error));
    } catch (error) {
      throw Exception('Erro inesperado: $error');
    }
  }

  @override
  Future<DevelopmentPlanModel> updateItemStatus({
    required String authToken,
    required String pdiId,
    required String itemId,
    required String status,
  }) async {
    try {
      final response = await _dio.patch(
        '/users/me/development-plan/$pdiId/items/$itemId',
        data: {'status': status},
        options: Options(headers: _authHeaders(authToken)),
      );
      return DevelopmentPlanModel.fromJson(_responseMap(response.data));
    } on DioException catch (error) {
      throw Exception(_extractErrorMessage(error));
    } catch (error) {
      throw Exception('Erro inesperado: $error');
    }
  }

  Map<String, dynamic> _responseMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    throw Exception('Resposta da API em formato invalido');
  }

  Map<String, String> _authHeaders(String authToken) {
    return {'Authorization': 'Bearer $authToken'};
  }

  String _extractErrorMessage(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout) {
      return 'Tempo de conexao esgotado';
    }

    if (error.type == DioExceptionType.receiveTimeout) {
      return 'Tempo de resposta esgotado';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Nao foi possivel alcancar a API em ${ChatRepositoryImpl.apiBaseUrl}.';
    }

    final data = error.response?.data;
    if (data is Map<String, dynamic> && data['detail'] is String) {
      return data['detail'] as String;
    }

    if (error.response?.statusCode == 404) {
      return 'PDI nao encontrado';
    }

    return 'Falha ao carregar PDI';
  }
}
