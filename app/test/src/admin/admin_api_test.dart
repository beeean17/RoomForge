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
