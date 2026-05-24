enum BackendMode {
  firebase,
  legacyApi;

  static BackendMode fromEnvironmentValue(String value) {
    switch (value) {
      case 'firebase':
        return BackendMode.firebase;
      case 'legacy_api':
        return BackendMode.legacyApi;
      default:
        throw ArgumentError.value(
          value,
          'value',
          'Expected ROOMFORGE_BACKEND_MODE to be firebase or legacy_api.',
        );
    }
  }
}

class BackendModeConfig {
  static const environmentValue = String.fromEnvironment(
    'ROOMFORGE_BACKEND_MODE',
    defaultValue: 'firebase',
  );

  static BackendMode get current {
    return BackendMode.fromEnvironmentValue(environmentValue);
  }

  static bool get isFirebaseDefault {
    return current == BackendMode.firebase;
  }

  static bool get isLegacyApi {
    return current == BackendMode.legacyApi;
  }
}
