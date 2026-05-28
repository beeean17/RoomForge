class EditorConfig {
  static const editorUrl = String.fromEnvironment(
    'ROOMFORGE_EDITOR_URL',
    defaultValue: 'http://localhost:9239',
  );
}
