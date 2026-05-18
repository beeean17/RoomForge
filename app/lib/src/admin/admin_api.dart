import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api/api_config.dart';
import '../auth/auth_repository.dart';

class AdminUser {
  const AdminUser({
    required this.id,
    required this.firebaseUid,
    required this.role,
    this.email,
    this.displayName,
  });

  final int id;
  final String firebaseUid;
  final String? email;
  final String? displayName;
  final String role;

  factory AdminUser.fromJson(Map<String, Object?> json) {
    return AdminUser(
      id: json['id'] as int,
      firebaseUid: json['firebase_uid'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      role: json['role'] as String,
    );
  }
}

class AdminSession {
  const AdminSession({required this.admin, required this.capabilities});

  final AdminUser admin;
  final List<String> capabilities;

  factory AdminSession.fromJson(Map<String, Object?> json) {
    final capabilities = json['capabilities'] as List<Object?>;
    return AdminSession(
      admin: AdminUser.fromJson(json['admin'] as Map<String, Object?>),
      capabilities: capabilities.cast<String>(),
    );
  }
}

class AdminApi {
  AdminApi({
    required this.authRepository,
    http.Client? client,
    String baseUrl = ApiConfig.baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUri = Uri.parse(baseUrl);

  final AuthRepository authRepository;
  final http.Client _client;
  final Uri _baseUri;

  Future<AdminSession> loadSession() async {
    final response = await _client.get(
      _baseUri.resolve('/admin/session'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    return AdminSession.fromJson(body['data'] as Map<String, Object?>);
  }

  Future<Map<String, String>> _headers() async {
    final token = await authRepository.idToken();
    if (token == null || token.isEmpty) {
      throw const AdminApiException('No Firebase ID token is available.');
    }

    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Map<String, Object?> _decodeEnvelope(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, Object?>;
    final error = body['error'];
    if (response.statusCode >= 400 || error != null) {
      if (error is Map<String, Object?>) {
        final code = error['code']?.toString();
        throw AdminApiException(
          error['message']?.toString() ?? 'Admin API request failed.',
          code: code,
        );
      }
      throw const AdminApiException('Admin API request failed.');
    }
    return body;
  }
}

class AdminApiException implements Exception {
  const AdminApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
