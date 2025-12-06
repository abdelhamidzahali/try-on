import 'package:envisionfit/models/user.dart';
import 'package:envisionfit/models/clothing_item.dart';
import 'package:envisionfit/models/generated_image.dart';

enum TryOnStatus {
  pending,
  processing,
  completed,
  failed,
}

class TryOnSession {
  final String id;
  final String userId;
  final String userPhotoPath;
  final String clothingId;
  final String clothingPhotoPath;
  // Pre-computed clothing description metadata
  final String? clothingCategory;
  final String? clothingName;
  final String? clothingGender; // 'Gentleman' or 'Lady'
  final TryOnStatus status;
  final GeneratedImage? result;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TryOnSession({
    required this.id,
    required this.userId,
    required this.userPhotoPath,
    required this.clothingId,
    required this.clothingPhotoPath,
    this.clothingCategory,
    this.clothingName,
    this.clothingGender,
    required this.status,
    this.result,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  String get statusText {
    switch (status) {
      case TryOnStatus.pending:
        return 'Pending';
      case TryOnStatus.processing:
        return 'Processing...';
      case TryOnStatus.completed:
        return 'Completed';
      case TryOnStatus.failed:
        return 'Failed';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userPhotoPath': userPhotoPath,
        'clothingId': clothingId,
        'clothingPhotoPath': clothingPhotoPath,
        'clothingCategory': clothingCategory,
        'clothingName': clothingName,
        'clothingGender': clothingGender,
        'status': status.name,
        'result': result?.toJson(),
        'errorMessage': errorMessage,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory TryOnSession.fromJson(Map<String, dynamic> json) {
    TryOnStatus status;
    try {
      status = TryOnStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TryOnStatus.pending,
      );
    } catch (e) {
      status = TryOnStatus.pending;
    }

    return TryOnSession(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      userPhotoPath: json['userPhotoPath'] ?? '',
      clothingId: json['clothingId'] ?? '',
      clothingPhotoPath: json['clothingPhotoPath'] ?? '',
      clothingCategory: json['clothingCategory'],
      clothingName: json['clothingName'],
      clothingGender: json['clothingGender'],
      status: status,
      result: json['result'] != null ? GeneratedImage.fromJson(json['result']) : null,
      errorMessage: json['errorMessage'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  TryOnSession copyWith({
    String? id,
    String? userId,
    String? userPhotoPath,
    String? clothingId,
    String? clothingPhotoPath,
    String? clothingCategory,
    String? clothingName,
    String? clothingGender,
    TryOnStatus? status,
    GeneratedImage? result,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      TryOnSession(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        userPhotoPath: userPhotoPath ?? this.userPhotoPath,
        clothingId: clothingId ?? this.clothingId,
        clothingPhotoPath: clothingPhotoPath ?? this.clothingPhotoPath,
        clothingCategory: clothingCategory ?? this.clothingCategory,
        clothingName: clothingName ?? this.clothingName,
        clothingGender: clothingGender ?? this.clothingGender,
        status: status ?? this.status,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}