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

  final String id;
  final String userId;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RoomProject.fromJson(Map<String, Object?> json) {
    return RoomProject(
      id: _stringId(json['id']),
      userId: _stringId(json['user_id']),
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
    this.captureSessionId,
    this.captureImageId,
    this.captureImageRole,
  });

  final String id;
  final String projectId;
  final String userId;
  final String originalFilename;
  final String storedName;
  final String contentType;
  final int byteSize;
  final int? widthPx;
  final int? heightPx;
  final String? captureSessionId;
  final String? captureImageId;
  final String? captureImageRole;
  final String sha256Hex;
  final String retentionStatus;
  final DateTime uploadedAt;

  factory SourceImage.fromJson(Map<String, Object?> json) {
    return SourceImage(
      id: _stringId(json['id']),
      projectId: _stringId(json['project_id']),
      userId: _stringId(json['user_id']),
      originalFilename: json['original_filename'] as String,
      storedName: json['stored_name'] as String,
      contentType: json['content_type'] as String,
      byteSize: json['byte_size'] as int,
      widthPx: json['width_px'] as int?,
      heightPx: json['height_px'] as int?,
      captureSessionId: json['capture_session_id'] as String?,
      captureImageId: json['capture_image_id'] as String?,
      captureImageRole: json['capture_image_role'] as String?,
      sha256Hex: json['sha256_hex'] as String,
      retentionStatus: json['retention_status'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
    );
  }
}

class CaptureSession {
  const CaptureSession({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.roomDimensionsId,
    required this.captureMethod,
    required this.depthEnabled,
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.completedAt,
    this.notes,
  });

  final String id;
  final String projectId;
  final String userId;
  final String roomDimensionsId;
  final String captureMethod;
  final bool depthEnabled;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CaptureSession.fromJson(Map<String, Object?> json) {
    return CaptureSession(
      id: _stringId(json['id'] ?? json['capture_session_id']),
      projectId: _stringId(json['project_id']),
      userId: _stringId(json['user_id'] ?? json['owner_uid']),
      roomDimensionsId: json['room_dimensions_id'] as String,
      captureMethod: json['capture_method'] as String,
      depthEnabled: json['depth_enabled'] as bool,
      startedAt: json['started_at'] == null
          ? null
          : DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] == null
          ? null
          : DateTime.parse(json['completed_at'] as String),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CaptureImage {
  const CaptureImage({
    required this.id,
    required this.captureSessionId,
    required this.projectId,
    required this.userId,
    required this.sourceImageId,
    required this.role,
    required this.storagePath,
    required this.contentType,
    required this.widthPx,
    required this.heightPx,
    required this.createdAt,
    required this.updatedAt,
    this.captureOrder,
    this.guidanceState,
  });

  final String id;
  final String captureSessionId;
  final String projectId;
  final String userId;
  final String sourceImageId;
  final String role;
  final String storagePath;
  final String contentType;
  final int widthPx;
  final int heightPx;
  final int? captureOrder;
  final String? guidanceState;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CaptureImage.fromJson(Map<String, Object?> json) {
    return CaptureImage(
      id: _stringId(json['id'] ?? json['capture_image_id']),
      captureSessionId: _stringId(json['capture_session_id']),
      projectId: _stringId(json['project_id']),
      userId: _stringId(json['user_id'] ?? json['owner_uid']),
      sourceImageId: _stringId(json['source_image_id']),
      role: json['role'] as String,
      storagePath: json['storage_path'] as String,
      contentType: json['content_type'] as String,
      widthPx: json['width_px'] as int,
      heightPx: json['height_px'] as int,
      captureOrder: json['capture_order'] as int?,
      guidanceState: json['guidance_state'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CaptureSessionSnapshot {
  const CaptureSessionSnapshot({required this.session, required this.images});

  final CaptureSession session;
  final List<CaptureImage> images;

  List<String> get availableRoles {
    final roles = <String>{};
    for (final image in images) {
      roles.add(image.role);
    }
    return roles.toList(growable: false);
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

  final String projectId;
  final String userId;
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
      projectId: _stringId(json['project_id']),
      userId: _stringId(json['user_id']),
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

  final String id;
  final String projectId;
  final String userId;
  final String sourceImageId;
  final String status;
  final String statusLabel;
  final bool terminal;
  final String provider;
  final String? retryOfJobId;
  final String? failureReasonCode;
  final String? failureReasonMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ReconstructionJob.fromJson(Map<String, Object?> json) {
    return ReconstructionJob(
      id: _stringId(json['id']),
      projectId: _stringId(json['project_id']),
      userId: _stringId(json['user_id']),
      sourceImageId: _stringId(json['source_image_id']),
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      terminal: json['terminal'] as bool,
      provider: json['provider'] as String,
      retryOfJobId: json['retry_of_job_id'] == null
          ? null
          : _stringId(json['retry_of_job_id']),
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
    this.schemaVersion = 1,
    this.exportVersion = 1,
  });

  final String id;
  final String projectId;
  final String userId;
  final Map<String, Object?> roomDimensions;
  final Map<String, Object?> floorPlan;
  final Map<String, Object?> sourceMetadata;
  final List<Object?> furnitureObjects;
  final Map<String, Object?> editorScene;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;
  final int exportVersion;

  factory SavedLayout.fromJson(Map<String, Object?> json) {
    return SavedLayout(
      id: _stringId(json['id']),
      projectId: _stringId(json['project_id']),
      userId: _stringId(json['user_id']),
      roomDimensions: Map<String, Object?>.from(json['room_dimensions'] as Map),
      floorPlan: Map<String, Object?>.from(json['floor_plan'] as Map),
      sourceMetadata: Map<String, Object?>.from(json['source_metadata'] as Map),
      furnitureObjects: (json['furniture_objects'] as List).cast<Object?>(),
      editorScene: Map<String, Object?>.from(json['editor_scene'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      exportVersion: (json['export_version'] as num?)?.toInt() ?? 1,
    );
  }
}

class OpenCvResultRef {
  const OpenCvResultRef({required this.id});

  final String id;
}

class ConfirmedGeometryRef {
  const ConfirmedGeometryRef({required this.id});

  final String id;
}

class FloorPlanRef {
  const FloorPlanRef({required this.id});

  final String id;
}

class SceneUnderstandingResultRef {
  const SceneUnderstandingResultRef({required this.id});

  final String id;
}

abstract class ProjectApi {
  const ProjectApi({required this.authRepository});

  final AuthRepository authRepository;

  Future<List<RoomProject>> listProjects();

  Future<RoomProject> createProject({
    required String name,
    String? description,
  });

  Future<RoomProject> getProject(String projectId);

  Future<RoomProject> updateProject({
    required String projectId,
    required String name,
    String? description,
  });

  Future<void> deleteProject(String projectId);

  Future<SourceImage> uploadSourceImage({
    required String projectId,
    required String filename,
    required String contentType,
    required Uint8List bytes,
    int? widthPx,
    int? heightPx,
    void Function(double progress)? onProgress,
  });

  Future<CaptureSession> createCaptureSession({
    required String projectId,
    bool depthEnabled = false,
    String? notes,
  });

  Future<CaptureSessionSnapshot?> loadLatestCaptureSession({
    required String projectId,
  });

  Future<CaptureImage> uploadCaptureImage({
    required String projectId,
    required String captureSessionId,
    required String role,
    required String filename,
    required String contentType,
    required Uint8List bytes,
    int? widthPx,
    int? heightPx,
    int? captureOrder,
    void Function(double progress)? onProgress,
  });

  Future<RoomDimensions> saveRoomDimensions({
    required String projectId,
    required double widthValue,
    required double depthValue,
    double? heightValue,
  });

  Future<RoomDimensions?> getRoomDimensions({required String projectId});

  Future<ReconstructionJob> createReconstructionJob({
    required String projectId,
    required String sourceImageId,
  });

  Future<ReconstructionJob> getReconstructionJob({
    required String projectId,
    required String jobId,
  });

  Future<ReconstructionJob> updateReconstructionJobStatus({
    required String projectId,
    required String jobId,
    required String status,
    required String reasonCode,
    required String reasonMessage,
    String? failureReasonCode,
    String? failureReasonMessage,
  });

  Future<ReconstructionJob> retryReconstructionJob({
    required String projectId,
    required String jobId,
  });

  Future<OpenCvResultRef> persistOpenCvResult({
    required String projectId,
    required String jobId,
    required String sourceImageId,
    required Map<String, Object?> candidateGeometry,
    required double? confidence,
    required String algorithm,
    String coordinateSpace = 'image_pixels',
    String? qualityStatus,
    String? failureReasonCode,
    String? failureReason,
    String? openCvVersion,
  });

  Future<ConfirmedGeometryRef> persistConfirmedGeometry({
    required String projectId,
    required String jobId,
    required String sourceImageId,
    required String? openCvResultId,
    required List<Map<String, Object?>> points,
    String coordinateSpace = 'image_pixels',
    String geometryKind = 'room_boundary',
    String? correctionMethod,
  });

  Future<FloorPlanRef> persistFloorPlanResult({
    required String projectId,
    required String jobId,
    required String sourceImageId,
    required String confirmedGeometryId,
    required Map<String, Object?> referenceLine,
    required double referenceLengthValue,
    required Map<String, Object?> imageGeometry,
    required Map<String, Object?> metricGeometry,
    required Map<String, Object?> perspectiveAssumptions,
    String unit = 'meters',
    String? qualityStatus,
  });

  Future<SceneUnderstandingResultRef> persistSceneUnderstandingResult({
    required String projectId,
    required Map<String, Object?> sceneUnderstandingResult,
  });

  Future<Map<String, Object?>?> loadLatestSceneUnderstandingResult({
    required String projectId,
  });

  Future<SavedLayout> saveLayout({
    required String projectId,
    required Map<String, Object?> roomDimensions,
    required Map<String, Object?> floorPlan,
    required Map<String, Object?> sourceMetadata,
    required List<Map<String, Object?>> furnitureObjects,
    required Map<String, Object?> editorScene,
  });

  Future<SavedLayout> loadLatestLayout({required String projectId});

  Future<Map<String, Object?>> exportLatestLayout({required String projectId});
}

class LegacyProjectApi extends ProjectApi {
  LegacyProjectApi({
    required super.authRepository,
    http.Client? client,
    String baseUrl = ApiConfig.baseUrl,
  }) : _client = client ?? http.Client(),
       _baseUri = Uri.parse(baseUrl);

  final http.Client _client;
  final Uri _baseUri;

  @override
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

  @override
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

  @override
  Future<RoomProject> getProject(String projectId) async {
    final response = await _client.get(
      _baseUri.resolve('/room-projects/$projectId'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return RoomProject.fromJson(data['project'] as Map<String, Object?>);
  }

  @override
  Future<RoomProject> updateProject({
    required String projectId,
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

  @override
  Future<void> deleteProject(String projectId) async {
    final response = await _client.delete(
      _baseUri.resolve('/room-projects/$projectId'),
      headers: await _headers(),
    );
    if (response.statusCode == 204) {
      return;
    }
    _decodeEnvelope(response);
  }

  @override
  Future<SourceImage> uploadSourceImage({
    required String projectId,
    required String filename,
    required String contentType,
    required Uint8List bytes,
    int? widthPx,
    int? heightPx,
    void Function(double progress)? onProgress,
  }) async {
    onProgress?.call(0.05);
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
    final sourceImage = SourceImage.fromJson(
      data['source_image'] as Map<String, Object?>,
    );
    onProgress?.call(1);
    return sourceImage;
  }

  @override
  Future<CaptureSession> createCaptureSession({
    required String projectId,
    bool depthEnabled = false,
    String? notes,
  }) {
    throw const ProjectApiException(
      'Guided capture sessions require the Firebase backend.',
      code: 'unsupported_backend',
    );
  }

  @override
  Future<CaptureSessionSnapshot?> loadLatestCaptureSession({
    required String projectId,
  }) async {
    return null;
  }

  @override
  Future<CaptureImage> uploadCaptureImage({
    required String projectId,
    required String captureSessionId,
    required String role,
    required String filename,
    required String contentType,
    required Uint8List bytes,
    int? widthPx,
    int? heightPx,
    int? captureOrder,
    void Function(double progress)? onProgress,
  }) {
    throw const ProjectApiException(
      'Guided capture image upload requires the Firebase backend.',
      code: 'unsupported_backend',
    );
  }

  @override
  Future<RoomDimensions> saveRoomDimensions({
    required String projectId,
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

  @override
  Future<RoomDimensions?> getRoomDimensions({required String projectId}) async {
    try {
      final response = await _client.get(
        _baseUri.resolve('/room-projects/$projectId/dimensions'),
        headers: await _headers(),
      );
      final body = _decodeEnvelope(response);
      final data = body['data'] as Map<String, Object?>;
      return RoomDimensions.fromJson(
        data['dimensions'] as Map<String, Object?>,
      );
    } on ProjectApiException catch (error) {
      if (error.code == 'not_found') {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<ReconstructionJob> createReconstructionJob({
    required String projectId,
    required String sourceImageId,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/room-projects/$projectId/reconstruction-jobs'),
      headers: await _headers(),
      body: jsonEncode({'source_image_id': _jsonId(sourceImageId)}),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return ReconstructionJob.fromJson(data['job'] as Map<String, Object?>);
  }

  @override
  Future<ReconstructionJob> getReconstructionJob({
    required String projectId,
    required String jobId,
  }) async {
    final response = await _client.get(
      _baseUri.resolve('/room-projects/$projectId/reconstruction-jobs/$jobId'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return ReconstructionJob.fromJson(data['job'] as Map<String, Object?>);
  }

  @override
  Future<ReconstructionJob> updateReconstructionJobStatus({
    required String projectId,
    required String jobId,
    required String status,
    required String reasonCode,
    required String reasonMessage,
    String? failureReasonCode,
    String? failureReasonMessage,
  }) async {
    final response = await _client.patch(
      _baseUri.resolve(
        '/room-projects/$projectId/reconstruction-jobs/$jobId/status',
      ),
      headers: await _headers(),
      body: jsonEncode({
        'status': status,
        'reason_code': reasonCode,
        'reason_message': reasonMessage,
        'failure_reason_code': failureReasonCode,
        'failure_reason_message': failureReasonMessage,
      }),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return ReconstructionJob.fromJson(data['job'] as Map<String, Object?>);
  }

  @override
  Future<ReconstructionJob> retryReconstructionJob({
    required String projectId,
    required String jobId,
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

  @override
  Future<OpenCvResultRef> persistOpenCvResult({
    required String projectId,
    required String jobId,
    required String sourceImageId,
    required Map<String, Object?> candidateGeometry,
    required double? confidence,
    required String algorithm,
    String coordinateSpace = 'image_pixels',
    String? qualityStatus,
    String? failureReasonCode,
    String? failureReason,
    String? openCvVersion,
  }) async {
    final candidateGeometryPayload = _snakeCaseJsonMap(candidateGeometry);
    final enrichedCandidateGeometry = <String, Object?>{
      ...candidateGeometryPayload,
      'source_image_id': sourceImageId,
    };
    if (qualityStatus != null) {
      enrichedCandidateGeometry['quality_status'] = qualityStatus;
    }
    if (failureReasonCode != null) {
      enrichedCandidateGeometry['failure_reason_code'] = failureReasonCode;
    }
    if (failureReason != null) {
      enrichedCandidateGeometry['failure_reason'] = failureReason;
    }
    if (openCvVersion != null) {
      enrichedCandidateGeometry['opencv_version'] = openCvVersion;
    }
    final response = await _client.post(
      _baseUri.resolve('/room-projects/$projectId/opencv-results'),
      headers: await _headers(),
      body: jsonEncode({
        'job_id': _jsonId(jobId),
        'coordinate_space': coordinateSpace,
        'candidate_geometry': enrichedCandidateGeometry,
        'confidence': confidence,
        'algorithm': algorithm,
      }),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    final result = data['opencv_result'] as Map<String, Object?>;
    return OpenCvResultRef(id: _stringId(result['id']));
  }

  @override
  Future<ConfirmedGeometryRef> persistConfirmedGeometry({
    required String projectId,
    required String jobId,
    required String sourceImageId,
    required String? openCvResultId,
    required List<Map<String, Object?>> points,
    String coordinateSpace = 'image_pixels',
    String geometryKind = 'room_boundary',
    String? correctionMethod,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/room-projects/$projectId/confirmed-geometries'),
      headers: await _headers(),
      body: jsonEncode({
        'opencv_result_id': openCvResultId == null
            ? null
            : _jsonId(openCvResultId),
        'coordinate_space': coordinateSpace,
        'geometry_kind': geometryKind,
        'points': points,
      }),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    final geometry = data['confirmed_geometry'] as Map<String, Object?>;
    return ConfirmedGeometryRef(id: _stringId(geometry['id']));
  }

  @override
  Future<FloorPlanRef> persistFloorPlanResult({
    required String projectId,
    required String jobId,
    required String sourceImageId,
    required String confirmedGeometryId,
    required Map<String, Object?> referenceLine,
    required double referenceLengthValue,
    required Map<String, Object?> imageGeometry,
    required Map<String, Object?> metricGeometry,
    required Map<String, Object?> perspectiveAssumptions,
    String unit = 'meters',
    String? qualityStatus,
  }) async {
    final response = await _client.post(
      _baseUri.resolve('/room-projects/$projectId/floor-plans'),
      headers: await _headers(),
      body: jsonEncode({
        'confirmed_geometry_id': _jsonId(confirmedGeometryId),
        'reference_line': _snakeCaseJsonMap(referenceLine),
        'reference_length_value': referenceLengthValue,
        'unit': unit,
      }),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    final floorPlan = data['floor_plan'] as Map<String, Object?>;
    return FloorPlanRef(id: _stringId(floorPlan['id']));
  }

  @override
  Future<SceneUnderstandingResultRef> persistSceneUnderstandingResult({
    required String projectId,
    required Map<String, Object?> sceneUnderstandingResult,
  }) {
    throw const ProjectApiException(
      'Scene understanding persistence requires the Firebase backend.',
      code: 'unsupported_backend',
    );
  }

  @override
  Future<Map<String, Object?>?> loadLatestSceneUnderstandingResult({
    required String projectId,
  }) async {
    return null;
  }

  @override
  Future<SavedLayout> saveLayout({
    required String projectId,
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

  @override
  Future<SavedLayout> loadLatestLayout({required String projectId}) async {
    final response = await _client.get(
      _baseUri.resolve('/room-projects/$projectId/layouts/latest'),
      headers: await _headers(),
    );
    final body = _decodeEnvelope(response);
    final data = body['data'] as Map<String, Object?>;
    return SavedLayout.fromJson(data['layout'] as Map<String, Object?>);
  }

  @override
  Future<Map<String, Object?>> exportLatestLayout({
    required String projectId,
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

String _stringId(Object? value) {
  if (value == null) {
    throw const FormatException('ID value is required.');
  }
  return value.toString();
}

Object _jsonId(String value) {
  return int.tryParse(value) ?? value;
}

Map<String, Object?> _snakeCaseJsonMap(Map<String, Object?> value) {
  return {
    for (final entry in value.entries)
      _snakeCaseKey(entry.key): _snakeCaseJsonValue(entry.value),
  };
}

Object? _snakeCaseJsonValue(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        _snakeCaseKey(entry.key.toString()): _snakeCaseJsonValue(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(_snakeCaseJsonValue).toList();
  }
  return value;
}

String _snakeCaseKey(String value) {
  return value.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9])[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  );
}
