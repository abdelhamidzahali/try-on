class GeneratedImage {
  final String id;
  final String userId;
  final String imagePath;
  final String prompt;
  /// Optional clothing description returned by backend to help retail search.
  final String? clothingDescription;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GeneratedImage({
    required this.id,
    required this.userId,
    required this.imagePath,
    required this.prompt,
    this.clothingDescription,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'imagePath': imagePath,
        'prompt': prompt,
        'clothingDescription': clothingDescription,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory GeneratedImage.fromJson(Map<String, dynamic> json) => GeneratedImage(
        id: json['id'] ?? '',
        userId: json['userId'] ?? '',
        imagePath: json['imagePath'] ?? '',
        prompt: json['prompt'] ?? '',
        clothingDescription: json['clothingDescription'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      );

  GeneratedImage copyWith({
    String? id,
    String? userId,
    String? imagePath,
    String? prompt,
    String? clothingDescription,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      GeneratedImage(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        imagePath: imagePath ?? this.imagePath,
        prompt: prompt ?? this.prompt,
        clothingDescription: clothingDescription ?? this.clothingDescription,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}