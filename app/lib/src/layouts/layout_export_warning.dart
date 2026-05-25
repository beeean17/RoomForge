const layoutNeedsReviewLabel = 'Needs review';
const layoutNeedsReviewSaveWarning =
    'Needs review before save. Press Save layout again to continue.';
const layoutNeedsReviewExportWarning =
    'Needs review before export. Press Export JSON again to export the latest saved layout.';

bool layoutStatusNeedsReview(String? status) {
  return status == 'review_required';
}

bool layoutExportNeedsReviewWarning(Map<String, Object?> exportPayload) {
  if (exportPayload['review_required'] == true) {
    return true;
  }
  if (layoutStatusNeedsReview(
    exportPayload['reconstruction_status']?.toString(),
  )) {
    return true;
  }
  final sourceMetadata = _recordValue(exportPayload['source_metadata']);
  return layoutStatusNeedsReview(
    sourceMetadata['reconstruction_status']?.toString(),
  );
}

Map<String, Object?> _recordValue(Object? value) {
  return value is Map ? Map<String, Object?>.from(value) : {};
}
