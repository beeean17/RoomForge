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

class AdminJob {
  const AdminJob({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.sourceImageId,
    required this.status,
    required this.statusLabel,
    required this.terminal,
    required this.provider,
    required this.createdAt,
    required this.updatedAt,
    this.retryOfJobId,
    this.failureReasonCode,
    this.failureReasonMessage,
  });

  final int id;
  final int projectId;
  final int userId;
  final int sourceImageId;
  final String status;
  final String statusLabel;
  final bool terminal;
  final String provider;
  final int? retryOfJobId;
  final String? failureReasonCode;
  final String? failureReasonMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AdminJob.fromJson(Map<String, Object?> json) {
    return AdminJob(
      id: json['id'] as int,
      projectId: json['project_id'] as int,
      userId: json['user_id'] as int,
      sourceImageId: json['source_image_id'] as int,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      terminal: json['terminal'] as bool,
      provider: json['provider'] as String,
      retryOfJobId: json['retry_of_job_id'] as int?,
      failureReasonCode: json['failure_reason_code'] as String?,
      failureReasonMessage: json['failure_reason_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class AdminJobList {
  const AdminJobList({required this.jobs, required this.allowedStatuses});

  final List<AdminJob> jobs;
  final List<String> allowedStatuses;

  factory AdminJobList.fromJson(Map<String, Object?> json) {
    final jobs = json['jobs'] as List<Object?>;
    final allowedStatuses = json['allowed_statuses'] as List<Object?>;
    return AdminJobList(
      jobs: jobs.cast<Map<String, Object?>>().map(AdminJob.fromJson).toList(),
      allowedStatuses: allowedStatuses.cast<String>(),
    );
  }
}

class AdminJobTransition {
  const AdminJobTransition({
    required this.id,
    required this.jobId,
    required this.status,
    required this.actor,
    required this.createdAt,
    this.reasonCode,
    this.reasonMessage,
  });

  final int id;
  final int jobId;
  final String status;
  final String actor;
  final String? reasonCode;
  final String? reasonMessage;
  final DateTime createdAt;

  factory AdminJobTransition.fromJson(Map<String, Object?> json) {
    return AdminJobTransition(
      id: json['id'] as int,
      jobId: json['job_id'] as int,
      status: json['status'] as String,
      actor: json['actor'] as String,
      reasonCode: json['reason_code'] as String?,
      reasonMessage: json['reason_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class AdminJobDetail {
  const AdminJobDetail({
    required this.job,
    required this.retryCount,
    required this.transitions,
  });

  final AdminJob job;
  final int retryCount;
  final List<AdminJobTransition> transitions;

  factory AdminJobDetail.fromJson(Map<String, Object?> json) {
    final transitions = json['transitions'] as List<Object?>;
    return AdminJobDetail(
      job: AdminJob.fromJson(json['job'] as Map<String, Object?>),
      retryCount: json['retry_count'] as int,
      transitions: transitions
          .cast<Map<String, Object?>>()
          .map(AdminJobTransition.fromJson)
          .toList(),
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

  Future<AdminJobList> loadJobs({String? status}) async {
    final uri = _baseUri.resolve('/admin/jobs').replace(
      queryParameters: status == null ? null : {'status': status},
    );
    final response = await _client.get(uri, headers: await _headers());
    final body = _decodeEnvelope(response);
    return AdminJobList.fromJson(body['data'] as Map<String, Object?>);
  }

  Future<AdminJobDetail> loadJobDetail(int jobId) async {
    final response = await _client.get(
      _baseUri.resolve('/admin/jobs/$jobId'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    return AdminJobDetail.fromJson(body['data'] as Map<String, Object?>);
  }

  Future<Map<String, Object?>> loadJobArtifacts(int jobId) async {
    final response = await _client.get(
      _baseUri.resolve('/admin/jobs/$jobId/artifacts'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    return Map<String, Object?>.from(body['data'] as Map);
  }

  Future<AdminJobDetail> retryJob(int jobId) async {
    final response = await _client.post(
      _baseUri.resolve('/admin/jobs/$jobId/retry'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    return AdminJobDetail.fromJson(body['data'] as Map<String, Object?>);
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
