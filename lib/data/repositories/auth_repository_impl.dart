import 'package:dio/dio.dart';

import '../api_errors.dart';
import '../legal_versions.dart';
import 'chat_repository_impl.dart';

class AuthSessionData {
  final String authToken;
  final String userId;
  final String email;
  final String displayName;
  final String? termsVersion;
  final String? privacyVersion;

  const AuthSessionData({
    required this.authToken,
    required this.userId,
    required this.email,
    required this.displayName,
    this.termsVersion,
    this.privacyVersion,
  });
}

class UserStatusData {
  final bool hasCv;
  final bool hasEmbeddings;

  const UserStatusData({
    required this.hasCv,
    required this.hasEmbeddings,
  });
}

class AuthRepositoryImpl {
  AuthRepositoryImpl()
    : _dio = Dio(
        BaseOptions(
          baseUrl: ChatRepositoryImpl.apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

  final Dio _dio;

  Future<AuthSessionData> register({
    required String displayName,
    required String email,
    required String password,
    required bool termsAccepted,
    required bool privacyAccepted,
  }) async {
    final response = await _post(
      '/auth/register',
      data: {
        'display_name': displayName.trim(),
        'email': email.trim(),
        'password': password,
        ...buildRegisterConsentFields(
          termsAccepted: termsAccepted,
          privacyAccepted: privacyAccepted,
        ),
      },
    );
    return _parseAuthSession(response.data);
  }

  Future<AuthSessionData> login({
    required String email,
    required String password,
  }) async {
    final response = await _post(
      '/auth/login',
      data: {
        'email': email.trim(),
        'password': password,
      },
    );
    return _parseAuthSession(response.data);
  }

  Future<AuthSessionData> getCurrentUser(String authToken) async {
    try {
      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: _bearerHeaders(authToken)),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Resposta da API em formato invalido');
      }

      return AuthSessionData(
        authToken: authToken,
        userId: data['user_id'] as String? ?? '',
        email: data['email'] as String? ?? '',
        displayName: data['display_name'] as String? ?? '',
        termsVersion: data['terms_version'] as String?,
        privacyVersion: data['privacy_version'] as String?,
      );
    } on DioException catch (e) {
      rethrowApiError(
        e,
        fallback: 'Falha ao autenticar com a API',
        apiBaseUrl: ChatRepositoryImpl.apiBaseUrl,
      );
    }
  }

  Future<UserStatusData> getUserStatus(String authToken) async {
    try {
      final response = await _dio.get(
        '/users/me/status',
        options: Options(headers: _bearerHeaders(authToken)),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw Exception('Resposta da API em formato invalido');
      }

      return UserStatusData(
        hasCv: data['has_cv'] == true,
        hasEmbeddings: data['has_embeddings'] == true,
      );
    } on DioException catch (e) {
      rethrowApiError(
        e,
        fallback: 'Falha ao autenticar com a API',
        apiBaseUrl: ChatRepositoryImpl.apiBaseUrl,
      );
    }
  }

  Future<Response<dynamic>> _post(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    try {
      final response = await _dio.post(path, data: data);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Erro no servidor: ${response.statusCode}');
      }
      return response;
    } on DioException catch (e) {
      rethrowApiError(
        e,
        fallback: 'Falha ao autenticar com a API',
        apiBaseUrl: ChatRepositoryImpl.apiBaseUrl,
      );
    }
  }

  AuthSessionData _parseAuthSession(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw Exception('Resposta da API em formato invalido');
    }

    final token = data['access_token'] as String?;
    final user = data['user'];
    if (token == null || user is! Map<String, dynamic>) {
      throw Exception('Resposta de autenticacao incompleta');
    }

    return AuthSessionData(
      authToken: token,
      userId: user['user_id'] as String? ?? '',
      email: user['email'] as String? ?? '',
      displayName: user['display_name'] as String? ?? '',
      termsVersion: user['terms_version'] as String?,
      privacyVersion: user['privacy_version'] as String?,
    );
  }

  Map<String, String> _bearerHeaders(String authToken) {
    return {
      'Authorization': 'Bearer $authToken',
    };
  }
}
