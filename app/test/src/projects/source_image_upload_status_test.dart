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
}
