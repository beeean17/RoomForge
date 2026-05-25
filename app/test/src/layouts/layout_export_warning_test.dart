import 'package:app/src/layouts/layout_export_warning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('layout export warning', () {
    test('uses Needs review label for persisted review_required status', () {
      expect(layoutNeedsReviewLabel, 'Needs review');
      expect(layoutStatusNeedsReview('review_required'), isTrue);
      expect(layoutStatusNeedsReview('succeeded'), isFalse);
    });

    test('warns when exported layout review flag is true', () {
      expect(
        layoutExportNeedsReviewWarning(const {
          'review_required': true,
          'reconstruction_status': 'succeeded',
        }),
        isTrue,
      );
    });

    test('warns when exported layout source metadata needs review', () {
      expect(
        layoutExportNeedsReviewWarning(const {
          'review_required': false,
          'reconstruction_status': 'succeeded',
          'source_metadata': {'reconstruction_status': 'review_required'},
        }),
        isTrue,
      );
    });

    test('does not warn for a succeeded saved layout', () {
      expect(
        layoutExportNeedsReviewWarning(const {
          'review_required': false,
          'reconstruction_status': 'succeeded',
          'source_metadata': {'reconstruction_status': 'succeeded'},
        }),
        isFalse,
      );
    });
  });
}
