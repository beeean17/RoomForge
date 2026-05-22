import 'dart:convert';
import 'dart:typed_data';

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

class SourceImage {
  const SourceImage({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.originalFilename,
    required this.storedName,
    required this.contentType,
    required this.byteSize,
    required this.sha256Hex,
    required this.retentionStatus,
    required this.uploadedAt,
    this.widthPx,
    this.heightPx,
  });

  final int id;
  final int projectId;
  final int userId;
  final String originalFilename;
  final String storedName;
  final String contentType;
  final int byteSize;
  final int? widthPx;
  final int? heightPx;
  final String sha256Hex;
  final String retentionStatus;
  final DateTime uploadedAt;

  factory SourceImage.fromJson(Map<String, Object?> json) {
    return SourceImage(
      id: json['id'] as int,
      projectId: json['project_id'] as int,
      userId: json['user_id'] as int,
      originalFilename: json['original_filename'] as String,
      storedName: json['stored_name'] as String,
      contentType: json['content_type'] as String,
      byteSize: json['byte_size'] as int,
      widthPx: json['width_px'] as int?,
      heightPx: json['height_px'] as int?,
      sha256Hex: json['sha256_hex'] as String,
      retentionStatus: json['retention_status'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }
}

class RoomDimensions {
  const RoomDimensions({
    required this.projectId,
    required this.userId,
    required this.widthValue,
    required this.depthValue,
    required this.heightValue,
    required this.unit,
    required this.heightSource,
    required this.createdAt,
    required this.updatedAt,
  });

  final int projectId;
  final int userId;
  final double widthValue;
  final double depthValue;
  final double heightValue;
  final String unit;
  final String heightSource;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get usesDefaultHeight => heightSource == 'default';

  factory RoomDimensions.fromJson(Map<String, Object?> json) {
    return RoomDimensions(
      projectId: json['project_id'] as int,
      userId: json['user_id'] as int,
      widthValue: (json['width_value'] as num).toDouble(),
      depthValue: (json['depth_value'] as num).toDouble(),
      heightValue: (json['height_value'] as num).toDouble(),
      unit: json['unit'] as String,
      heightSource: json['height_source'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ReconstructionJob {
  const ReconstructionJob({
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

  factory ReconstructionJob.fromJson(Map<String, Object?> json) {
    return ReconstructionJob(
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

class SavedLayout {
  const SavedLayout({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.roomDimensions,
    required this.floorPlan,
    required this.sourceMetadata,
    required this.furnitureObjects,
    required this.editorScene,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int projectId;
  final int userId;
  final Map<String, Object?> roomDimensions;
  final Map<String, Object?> floorPlan;
  final Map<String, Object?> sourceMetadata;
  final List<Object?> furnitureObjects;
  final Map<String, Object?> editorScene;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SavedLayout.fromJson(Map<String, Object?> json) {
    return SavedLayout(
      id: json['id'] as int,
      projectId: json['project_id'] as int,
      userId: json['user_id'] as int,
      roomDimensions: Map<String, Object?>.from(
        json['room_dimensions'] as Map,
      ),
      floorPlan: Map<String, Object?>.from(json['floor_plan'] as Map),
      sourceMetadata: Map<String, Object?>.from(
        json['source_metadata'] as Map,
      ),
      furnitureObjects: (json['furniture_objects'] as List).cast<Object?>(),
      editorScene: Map<String, Object?>.from(json['editor_scene'] as Map),
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

  Future<RoomProject> getProject(int projectId) async {
    final response = await _client.get(
      _baseUri.resolve('/room-projects/$projectId'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return RoomProject.fromJson(data['project'] as Map<String, Object?>);
  }

  Future<RoomProject> updateProject({
    required int projectId,
    required String name,
    String? description,
  }) async {
    final response = await _client.put(
      _baseUri.resolve('/room-projects/$projectId'),
      headers: await _headers(),
      body: jsonEncode({'name': name, 'description': description}),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return RoomProject.fromJson(data['project'] as Map<String, Object?>);
  }

  Future<void> deleteProject(int projectId) async {
    final response = await _client.delete(
      _baseUri.resolve('/room-projects/$projectId'),
      headers: await _headers(),
    );
    if (response.statusCode == 204) {
      return;
    }
    _decodeEnvelope(response);
  }

  Future<SourceImage> uploadSourceImage({
    required int projectId,
    required String filename,
    required String contentType,
    required Uint8List bytes,
    int? widthPx,
    int? heightPx,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/room-projects/$projectId/source-images'),
      headers: await _headers(),
      body: jsonEncode({
        'filename': filename,
        'content_type': contentType,
        'byte_size': bytes.length,
        'image_base64': base64Encode(bytes),
        'width_px': widthPx,
        'height_px': heightPx,
      }),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return SourceImage.fromJson(data['source_image'] as Map<String, Object?>);
  }

  Future<RoomDimensions> saveRoomDimensions({
    required int projectId,
    required double widthValue,
    required double depthValue,
    double? heightValue,
  }) async {
    final response = await _client.put(
      _baseUri.resolve('/room-projects/$projectId/dimensions'),
      headers: await _headers(),
      body: jsonEncode({
        'width_value': widthValue,
        'depth_value': depthValue,
        'height_value': heightValue,
        'unit': 'meters',
      }),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return RoomDimensions.fromJson(data['dimensions'] as Map<String, Object?>);
  }

  Future<ReconstructionJob> createReconstructionJob({
    required int projectId,
    required int sourceImageId,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/room-projects/$projectId/reconstruction-jobs'),
      headers: await _headers(),
      body: jsonEncode({'source_image_id': sourceImageId}),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return ReconstructionJob.fromJson(data['job'] as Map<String, Object?>);
  }

  Future<ReconstructionJob> getReconstructionJob({
    required int projectId,
    required int jobId,
  }) async {
    final response = await _client.get(
      _baseUri.resolve('/room-projects/$projectId/reconstruction-jobs/$jobId'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return ReconstructionJob.fromJson(data['job'] as Map<String, Object?>);
  }

  Future<ReconstructionJob> retryReconstructionJob({
    required int projectId,
    required int jobId,
  }) async {
    final response = await _client.post(
      _baseUri.resolve(
        '/room-projects/$projectId/reconstruction-jobs/$jobId/retry',
      ),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return ReconstructionJob.fromJson(data['job'] as Map<String, Object?>);
  }

  Future<SavedLayout> saveLayout({
    required int projectId,
    required Map<String, Object?> roomDimensions,
    required Map<String, Object?> floorPlan,
    required Map<String, Object?> sourceMetadata,
    required List<Map<String, Object?>> furnitureObjects,
    required Map<String, Object?> editorScene,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/room-projects/$projectId/layouts'),
      headers: await _headers(),
      body: jsonEncode({
        'room_dimensions': roomDimensions,
        'floor_plan': floorPlan,
        'source_metadata': sourceMetadata,
        'furniture_objects': furnitureObjects,
        'editor_scene': editorScene,
      }),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return SavedLayout.fromJson(data['layout'] as Map<String, Object?>);
  }

  Future<SavedLayout> loadLatestLayout({required int projectId}) async {
    final response = await _client.get(
      _baseUri.resolve('/room-projects/$projectId/layouts/latest'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return SavedLayout.fromJson(data['layout'] as Map<String, Object?>);
  }

  Future<Map<String, Object?>> exportLatestLayout({
    required int projectId,
  }) async {
    final response = await _client.get(
      _baseUri.resolve('/room-projects/$projectId/layouts/latest/export'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return Map<String, Object?>.from(data['export'] as Map);
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
          code: error['code']?.toString(),
        );
      }
      throw const ProjectApiException('Project API request failed.');
    }
    return body;
  }
}

class ProjectApiException implements Exception {
  const ProjectApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
