import 'dart:async';
import 'dart:convert';

import 'package:app/src/admin/admin_api.dart';
import 'package:app/src/auth/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'AdminApi loadJobs sends status filter and parses allowed statuses',
    () async {
      late http.Request capturedRequest;
      final api = AdminApi(
        authRepository: const _TokenAuthRepository('admin-token'),
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          capturedRequest = request;
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://api.example.test/admin/jobs?status=review_required',
          );
          expect(request.headers['Authorization'], 'Bearer admin-token');

          return http.Response(
            jsonEncode({
              'data': {
                'allowed_statuses': [
                  'created',
                  'uploading',
                  'processing',
                  'review_required',
                  'succeeded',
                  'failed',
                  'timeout',
                  'cancelled',
                  'retrying',
                ],
                'jobs': [
                  {
                    'id': 9,
                    'project_id': 1,
                    'user_id': 42,
                    'source_image_id': 7,
                    'status': 'review_required',
                    'status_label': 'Needs review',
                    'terminal': false,
                    'provider': 'manual_assisted_opencv',
                    'retry_of_job_id': null,
                    'failure_reason_code': null,
                    'failure_reason_message': null,
                    'created_at': '2026-05-29T00:00:00Z',
                    'updated_at': '2026-05-29T00:00:01Z',
                  },
                ],
              },
              'error': null,
              'meta': {'request_id': 'req-1'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final jobs = await api.loadJobs(status: 'review_required');

      expect(capturedRequest.headers['Content-Type'], 'application/json');
      expect(jobs.allowedStatuses, [
        'created',
        'uploading',
        'processing',
        'review_required',
        'succeeded',
        'failed',
        'timeout',
        'cancelled',
        'retrying',
      ]);
      expect(jobs.jobs, hasLength(1));
      expect(jobs.jobs.single.status, 'review_required');
      expect(jobs.jobs.single.statusLabel, 'Needs review');
    },
  );

  test(
    'AdminApi loadJobs surfaces unauthorized admin access envelope',
    () async {
      final api = AdminApi(
        authRepository: const _TokenAuthRepository('user-token'),
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'data': null,
              'error': {
                'code': 'unauthorized',
                'message': 'Admin access is required.',
              },
              'meta': {'request_id': 'req-denied'},
            }),
            403,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await expectLater(
        api.loadJobs(),
        throwsA(
          isA<AdminApiException>()
              .having((error) => error.code, 'code', 'unauthorized')
              .having(
                (error) => error.message,
                'message',
                contains('Admin access is required'),
              ),
        ),
      );
    },
  );

  test('AdminApi loadJobDetail parses header and event trail', () async {
    late http.Request capturedRequest;
    final api = AdminApi(
      authRepository: const _TokenAuthRepository('admin-token'),
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        capturedRequest = request;
        expect(request.method, 'GET');
        expect(request.url.toString(), 'https://api.example.test/admin/jobs/9');
        expect(request.headers['Authorization'], 'Bearer admin-token');

        return http.Response(
          jsonEncode({
            'data': {
              'job': {
                'id': 9,
                'project_id': 1,
                'user_id': 42,
                'source_image_id': 7,
                'status': 'failed',
                'status_label': 'Failed',
                'terminal': true,
                'provider': 'manual_assisted_opencv',
                'retry_of_job_id': 3,
                'failure_reason_code': 'opencv_failed',
                'failure_reason_message': 'OpenCV candidate extraction failed.',
                'created_at': '2026-05-29T00:00:00Z',
                'updated_at': '2026-05-29T00:00:05Z',
              },
              'retry_count': 2,
              'transitions': [
                {
                  'id': 21,
                  'job_id': 9,
                  'status': 'failed',
                  'actor': 'worker',
                  'reason_code': 'opencv_failed',
                  'reason_message': 'OpenCV candidate extraction failed.',
                  'created_at': '2026-05-29T00:00:05Z',
                },
              ],
            },
            'error': null,
            'meta': {'request_id': 'req-detail'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final detail = await api.loadJobDetail(9);

    expect(capturedRequest.headers['Content-Type'], 'application/json');
    expect(detail.job.id, 9);
    expect(detail.job.projectId, 1);
    expect(detail.job.status, 'failed');
    expect(detail.job.provider, 'manual_assisted_opencv');
    expect(detail.job.retryOfJobId, 3);
    expect(detail.job.failureReasonCode, 'opencv_failed');
    expect(detail.job.createdAt.toUtc(), DateTime.utc(2026, 5, 29));
    expect(detail.job.updatedAt.toUtc(), DateTime.utc(2026, 5, 29, 0, 0, 5));
    expect(detail.retryCount, 2);
    expect(detail.transitions, hasLength(1));
    expect(detail.transitions.single.jobId, 9);
    expect(detail.transitions.single.status, 'failed');
    expect(detail.transitions.single.actor, 'worker');
    expect(detail.transitions.single.reasonCode, 'opencv_failed');
    expect(
      detail.transitions.single.reasonMessage,
      'OpenCV candidate extraction failed.',
    );
    expect(
      detail.transitions.single.createdAt.toUtc(),
      DateTime.utc(2026, 5, 29, 0, 0, 5),
    );
  });

  test(
    'AdminApi loadJobArtifacts keeps candidate and confirmed data separate',
    () async {
      late http.Request capturedRequest;
      final api = AdminApi(
        authRepository: const _TokenAuthRepository('admin-token'),
        baseUrl: 'https://api.example.test',
        client: MockClient((request) async {
          capturedRequest = request;
          expect(request.method, 'GET');
          expect(
            request.url.toString(),
            'https://api.example.test/admin/jobs/9/artifacts',
          );
          expect(request.headers['Authorization'], 'Bearer admin-token');

          return http.Response(
            jsonEncode({
              'data': {
                'job': {
                  'id': 9,
                  'project_id': 1,
                  'user_id': 42,
                  'source_image_id': 7,
                  'status': 'review_required',
                  'status_label': 'Needs review',
                  'terminal': false,
                  'provider': 'manual_assisted_opencv',
                  'retry_of_job_id': null,
                  'failure_reason_code': 'low_confidence',
                  'failure_reason_message': 'Review the candidate geometry.',
                  'created_at': '2026-05-29T00:00:00Z',
                  'updated_at': '2026-05-29T00:00:05Z',
                },
                'source_image': {'id': 7, 'access': 'restricted'},
                'candidate': {
                  'opencv_result_id': 11,
                  'coordinate_space': 'image_pixels',
                  'geometry': {
                    'points': [
                      {'x': 1, 'y': 2},
                    ],
                  },
                  'confidence': 0.72,
                  'algorithm': 'opencv-js-canny-hough-v1',
                },
                'confirmed': [
                  {
                    'id': 12,
                    'coordinate_space': 'image_pixels',
                    'geometry_kind': 'floor_polygon',
                    'points': [
                      {'x': 3, 'y': 4},
                    ],
                  },
                ],
                'calibration': [
                  {
                    'floor_plan_id': 13,
                    'unit': 'meters',
                    'width_value': 4.2,
                    'depth_value': 3.6,
                    'width_deviation_ratio': 0,
                    'depth_deviation_ratio': 0,
                    'aspect_ratio_error': 0,
                    'image_geometry': {'coordinate_space': 'image_pixels'},
                    'metric_geometry': {'coordinate_space': 'meters'},
                  },
                ],
              },
              'error': null,
              'meta': {'request_id': 'req-artifacts'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final artifacts = await api.loadJobArtifacts(9);

      expect(capturedRequest.headers['Content-Type'], 'application/json');
      final sourceImage = Map<String, Object?>.from(
        artifacts['source_image'] as Map,
      );
      final candidate = Map<String, Object?>.from(
        artifacts['candidate'] as Map,
      );
      final confirmed = artifacts['confirmed'] as List<Object?>;
      final calibration = artifacts['calibration'] as List<Object?>;
      final job = Map<String, Object?>.from(artifacts['job'] as Map);
      expect(sourceImage, {'id': 7, 'access': 'restricted'});
      expect(candidate['coordinate_space'], 'image_pixels');
      expect(candidate['confidence'], 0.72);
      expect(candidate['algorithm'], 'opencv-js-canny-hough-v1');
      expect(candidate.containsKey('confirmed'), isFalse);
      expect(job['failure_reason_code'], 'low_confidence');
      expect(confirmed, hasLength(1));
      expect(
        Map<String, Object?>.from(confirmed.single as Map)['coordinate_space'],
        'image_pixels',
      );
      expect(
        Map<String, Object?>.from(
          confirmed.single as Map,
        ).containsKey('candidate_geometry'),
        isFalse,
      );
      expect(calibration, hasLength(1));
      expect(
        Map<String, Object?>.from(calibration.single as Map)['metric_geometry'],
        {'coordinate_space': 'meters'},
      );
    },
  );

  test('AdminApi retryJob creates linked retry detail', () async {
    late http.Request capturedRequest;
    final api = AdminApi(
      authRepository: const _TokenAuthRepository('admin-token'),
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        capturedRequest = request;
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.example.test/admin/jobs/9/retry',
        );
        expect(request.headers['Authorization'], 'Bearer admin-token');

        return http.Response(
          jsonEncode({
            'data': {
              'job': {
                'id': 10,
                'project_id': 1,
                'user_id': 42,
                'source_image_id': 7,
                'status': 'retrying',
                'status_label': 'Retrying',
                'terminal': false,
                'provider': 'manual_assisted_opencv',
                'retry_of_job_id': 9,
                'failure_reason_code': null,
                'failure_reason_message': null,
                'created_at': '2026-05-29T00:01:00Z',
                'updated_at': '2026-05-29T00:01:00Z',
              },
              'retry_count': 0,
              'retry_of_job_id': 9,
              'transitions': [
                {
                  'id': 31,
                  'job_id': 10,
                  'status': 'retrying',
                  'actor': 'admin',
                  'reason_code': 'admin_retry_requested',
                  'reason_message': 'Admin requested reconstruction retry.',
                  'created_at': '2026-05-29T00:01:00Z',
                },
              ],
            },
            'error': null,
            'meta': {'request_id': 'req-retry'},
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final detail = await api.retryJob(9);

    expect(capturedRequest.headers['Content-Type'], 'application/json');
    expect(detail.job.id, 10);
    expect(detail.job.status, 'retrying');
    expect(detail.job.retryOfJobId, 9);
    expect(detail.transitions.single.actor, 'admin');
    expect(detail.transitions.single.reasonCode, 'admin_retry_requested');
  });

  test('AdminApi retryJob surfaces retry unavailable explanation', () async {
    final api = AdminApi(
      authRepository: const _TokenAuthRepository('admin-token'),
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': null,
            'error': {
              'code': 'retry_unavailable',
              'message':
                  'Retry is only available for failed or timed-out jobs.',
            },
            'meta': {'request_id': 'req-retry-denied'},
          }),
          409,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      api.retryJob(9),
      throwsA(
        isA<AdminApiException>()
            .having((error) => error.code, 'code', 'retry_unavailable')
            .having(
              (error) => error.message,
              'message',
              contains('failed or timed-out'),
            ),
      ),
    );
  });

  test('AdminApi search sends query and parses navigable context', () async {
    late http.Request capturedRequest;
    final api = AdminApi(
      authRepository: const _TokenAuthRepository('admin-token'),
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        capturedRequest = request;
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://api.example.test/admin/search?q=42',
        );
        expect(request.headers['Authorization'], 'Bearer admin-token');

        return http.Response(
          jsonEncode({
            'data': {
              'query': '42',
              'results': [
                {
                  'type': 'user',
                  'id': 42,
                  'label': 'user@example.com',
                  'context': {'email': 'user@example.com', 'role': 'user'},
                },
                {
                  'type': 'project',
                  'id': 42,
                  'label': 'Kitchen',
                  'context': {'user_id': 42},
                },
                {
                  'type': 'layout',
                  'id': 42,
                  'label': 'Layout 42',
                  'context': {'project_id': 42, 'user_id': 42},
                },
                {
                  'type': 'job',
                  'id': 42,
                  'label': 'Failed reconstruction job',
                  'context': {
                    'status': 'failed',
                    'project_id': 42,
                    'user_id': 42,
                    'provider': 'browser-opencv',
                  },
                },
              ],
            },
            'error': null,
            'meta': {'request_id': 'req-search'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final results = await api.search('42');

    expect(capturedRequest.headers['Content-Type'], 'application/json');
    expect(results.map((result) => result['type']), [
      'user',
      'project',
      'layout',
      'job',
    ]);
    expect(results[0]['label'], 'user@example.com');
    expect(results[0]['context'], {
      'email': 'user@example.com',
      'role': 'user',
    });
    expect(results[3]['context'], {
      'status': 'failed',
      'project_id': 42,
      'user_id': 42,
      'provider': 'browser-opencv',
    });
  });

  test('AdminApi search preserves empty result state', () async {
    final api = AdminApi(
      authRepository: const _TokenAuthRepository('admin-token'),
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': {'query': 'missing', 'results': []},
            'error': null,
            'meta': {'request_id': 'req-empty-search'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    expect(await api.search('missing'), isEmpty);
  });

  test('AdminApi loadJobDiagnosis parses provider and failure state', () async {
    late http.Request capturedRequest;
    final api = AdminApi(
      authRepository: const _TokenAuthRepository('admin-token'),
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        capturedRequest = request;
        expect(request.method, 'GET');
        expect(
          request.url.toString(),
          'https://api.example.test/admin/jobs/9/diagnosis',
        );
        expect(request.headers['Authorization'], 'Bearer admin-token');

        return http.Response(
          jsonEncode({
            'data': {
              'job': {
                'id': 9,
                'project_id': 1,
                'user_id': 42,
                'source_image_id': 7,
                'status': 'failed',
                'status_label': 'Failed',
                'terminal': true,
                'provider': 'manual_assisted_opencv',
                'retry_of_job_id': null,
                'failure_reason_code': 'opencv_failed',
                'failure_reason_message': 'OpenCV failed.',
                'created_at': '2026-05-29T00:00:00Z',
                'updated_at': '2026-05-29T00:00:05Z',
              },
              'provider_state': {
                'provider': 'manual_assisted_opencv',
                'status': 'failed',
                'active_job_count': 2,
                'recent_failure_state': {
                  'job_id': 9,
                  'status': 'failed',
                  'failure_reason_code': 'opencv_failed',
                  'failure_reason_message': 'OpenCV failed.',
                  'updated_at': '2026-05-29T00:00:05Z',
                },
                'gpu_lifecycle': {'enabled': false, 'state': 'not_enabled'},
                'failure_reason_code': 'opencv_failed',
                'failure_reason_message': 'OpenCV failed.',
              },
              'failure_source': {
                'source': 'opencv_candidate_detection',
                'reason_code': 'opencv_failed',
                'supported_sources': [
                  'input_quality',
                  'opencv_candidate_detection',
                  'user_calibration',
                  'api_handling',
                  'database_state',
                  'provider_processing',
                  'unknown',
                ],
              },
            },
            'error': null,
            'meta': {'request_id': 'req-diagnosis'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final diagnosis = await api.loadJobDiagnosis(9);

    expect(capturedRequest.headers['Content-Type'], 'application/json');
    final providerState = Map<String, Object?>.from(
      diagnosis['provider_state'] as Map,
    );
    final recentFailure = Map<String, Object?>.from(
      providerState['recent_failure_state'] as Map,
    );
    final gpuLifecycle = Map<String, Object?>.from(
      providerState['gpu_lifecycle'] as Map,
    );
    final failureSource = Map<String, Object?>.from(
      diagnosis['failure_source'] as Map,
    );
    expect(providerState['provider'], 'manual_assisted_opencv');
    expect(providerState['active_job_count'], 2);
    expect(recentFailure['failure_reason_code'], 'opencv_failed');
    expect(gpuLifecycle, {'enabled': false, 'state': 'not_enabled'});
    expect(failureSource['source'], 'opencv_candidate_detection');
    expect(failureSource['supported_sources'], contains('provider_processing'));
  });
}

class _TokenAuthRepository implements AuthRepository {
  const _TokenAuthRepository(this.token);

  final String token;

  @override
  Stream<AuthSession?> authStateChanges() => const Stream.empty();

  @override
  Future<String?> idToken() async => token;

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}
