class SaveResult {
  final bool success;
  final String message;

  const SaveResult({required this.success, required this.message});

  static SaveResult ok([String message = 'Saved successfully']) => SaveResult(success: true, message: message);
  static SaveResult fail(String message) => SaveResult(success: false, message: message);
}
