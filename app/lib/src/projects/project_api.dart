import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_repository.dart';
import '../api/api_config.dart';

class RoomProject {
  const RoomProject({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description,
  });

  final int id;
  final int userId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RoomProject.fromJson(Map<String, Object?> json) {
    return RoomProject(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ProjectApi {
  ProjectApi({
    required this.authRepository,
    http.Client? client,
    String baseUrl = ApiConfig.baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUri = Uri.parse(baseUrl);

  final AuthRepository authRepository;
  final http.Client _client;
  final Uri _baseUri;

  Future<List<RoomProject>> listProjects() async {
    final response = await _client.get(
      _baseUri.resolve('/room-projects'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    final projects = data['projects'] as List<Object?>;
    return projects
        .cast<Map<String, Object?>>()
        .map(RoomProject.fromJson)
        .toList();
  }

  Future<RoomProject> createProject({
    required String name,
    String? description,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/room-projects'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'description': description}),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return RoomProject.fromJson(data['project'] as Map<String, Object?>);
  }

  Future<Map<String, String>> _headers() async {
    final token = await authRepository.idToken();
    if (token == null || token.isEmpty) {
      throw const ProjectApiException('No Firebase ID token is available.');
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
        throw ProjectApiException(
          error['message']?.toString() ?? 'Project API request failed.',
        );
      }
      throw const ProjectApiException('Project API request failed.');
    }
    return body;
  }
}

class ProjectApiException implements Exception {
  const ProjectApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
