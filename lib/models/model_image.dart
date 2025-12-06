import 'dart:convert';

class ModelImage {
  final String id;
  final String path; // File path (mobile/desktop) or data URL / http URL (web)
  final DateTime createdAt;
  final bool isDefault;

  const ModelImage({
    required this.id,
    required this.path,
    required this.createdAt,
    this.isDefault = false,
  });

  ModelImage copyWith({
    String? id,
    String? path,
    DateTime? createdAt,
    bool? isDefault,
  }) {
    return ModelImage(
      id: id ?? this.id,
      path: path ?? this.path,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'createdAt': createdAt.toIso8601String(),
        'isDefault': isDefault,
      };

  static ModelImage fromJson(Map<String, dynamic> json) {
    return ModelImage(
      id: json['id'] as String,
      path: json['path'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  static String generateId() => 'model_${DateTime.now().millisecondsSinceEpoch}';
}
