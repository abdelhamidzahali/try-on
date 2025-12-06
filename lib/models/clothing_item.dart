enum ClothingCategory {
  shirt,
  pants,
  dress,
  jacket,
  shoes,
  accessories,
}

class ClothingItem {
  final String id;
  final String userId;
  final String name;
  final ClothingCategory category;
  final String? brand;
  final String color;
  final String imagePath;
  final String? description;
  final String? gender; // 'Gentleman' or 'Lady'
  final String? aiCategory; // Category from AI description
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClothingItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    this.brand,
    required this.color,
    required this.imagePath,
    this.description,
    this.gender,
    this.aiCategory,
    required this.createdAt,
    required this.updatedAt,
  });

  String get categoryName {
    switch (category) {
      case ClothingCategory.shirt:
        return 'Shirt';
      case ClothingCategory.pants:
        return 'Pants';
      case ClothingCategory.dress:
        return 'Dress';
      case ClothingCategory.jacket:
        return 'Jacket';
      case ClothingCategory.shoes:
        return 'Shoes';
      case ClothingCategory.accessories:
        return 'Accessories';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'category': category.name,
        'brand': brand,
        'color': color,
        'imagePath': imagePath,
        'description': description,
        'gender': gender,
        'aiCategory': aiCategory,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ClothingItem.fromJson(Map<String, dynamic> json) {
    ClothingCategory category;
    try {
      category = ClothingCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ClothingCategory.shirt,
      );
    } catch (e) {
      category = ClothingCategory.shirt;
    }

    return ClothingItem(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      category: category,
      brand: json['brand'],
      color: json['color'] ?? '',
      imagePath: json['imagePath'] ?? '',
      description: json['description'],
      gender: json['gender'],
      aiCategory: json['aiCategory'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  ClothingItem copyWith({
    String? id,
    String? userId,
    String? name,
    ClothingCategory? category,
    String? brand,
    String? color,
    String? imagePath,
    String? description,
    String? gender,
    String? aiCategory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ClothingItem(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        name: name ?? this.name,
        category: category ?? this.category,
        brand: brand ?? this.brand,
        color: color ?? this.color,
        imagePath: imagePath ?? this.imagePath,
        description: description ?? this.description,
        gender: gender ?? this.gender,
        aiCategory: aiCategory ?? this.aiCategory,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}