import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/projects/project_api.dart';
import 'package:app/src/projects/source_image_upload_status.dart';

void main() {
  test('upload status maps validation errors to validation state', () {
    expect(
      uploadStatusForProjectApiException(
        const ProjectApiException('Bad type', code: 'invalid_content_type'),
      ),
      SourceImageUploadStatus.validationError,
    );
    expect(
      uploadStatusForProjectApiException(
        const ProjectApiException(
          'Missing size',
          code: 'missing_image_dimensions',
        ),
      ),
      SourceImageUploadStatus.validationError,
    );
  });

  test(
    'upload status maps permission and metadata failures to recovery states',
    () {
      expect(
        uploadStatusForProjectApiException(
          const ProjectApiException('Denied', code: 'permission_denied'),
        ),
        SourceImageUploadStatus.permissionFailure,
      );
      expect(
        uploadRecoveryMessage(
          const ProjectApiException('Denied', code: 'permission_denied'),
        ),
        contains('retry'),
      );

      expect(
        uploadStatusForProjectApiException(
          const ProjectApiException(
            'Metadata failed',
            code: 'metadata_save_failed',
          ),
        ),
        SourceImageUploadStatus.metadataSaveFailed,
      );
      expect(
        uploadRecoveryMessage(
          const ProjectApiException(
            'Metadata failed',
            code: 'metadata_save_failed',
          ),
        ),
        contains('clean up'),
      );
    },
  );

  test('upload progress labels are accessible text', () {
    expect(uploadProgressLabel(null), 'Uploading');
    expect(uploadProgressLabel(0.42), 'Uploading 42%');
    expect(uploadProgressLabel(2), 'Uploading 100%');
  });

  test(
    'upload recovery actions expose retry only for recoverable failures',
    () {
      expect(
        sourceImageUploadActions(
          SourceImageUploadStatus.metadataSaveFailed,
        ).map((action) => action.id),
        [
          SourceImageUploadActionId.choosePhoto,
          SourceImageUploadActionId.retryUpload,
        ],
      );
      expect(
        sourceImageUploadActions(
          SourceImageUploadStatus.validationError,
        ).map((action) => action.id),
        [SourceImageUploadActionId.choosePhoto],
      );
    },
  );

  test(
    'upload accessibility summaries cover progress and recovery guidance',
    () {
      expect(
        sourceImageUploadAccessibilitySummary(
          status: SourceImageUploadStatus.uploading,
          progress: 0.42,
        ),
        contains('Uploading 42%'),
      );
      expect(
        sourceImageUploadAccessibilitySummary(
          status: SourceImageUploadStatus.metadataSaveFailed,
          message: uploadRecoveryMessage(
            const ProjectApiException(
              'Metadata failed',
              code: 'metadata_save_failed',
            ),
          ),
        ),
        allOf(contains('Metadata save failed'), contains('clean up')),
      );
      expect(
        sourceImageUploadAccessibilitySummary(
          status: SourceImageUploadStatus.permissionFailure,
          message: uploadRecoveryMessage(
            const ProjectApiException(
              'projects/other-user/source-images/source-1',
              code: 'permission_denied',
            ),
          ),
        ),
        isNot(contains('other-user')),
      );
    },
  );
}
