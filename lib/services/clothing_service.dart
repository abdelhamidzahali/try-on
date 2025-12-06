import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:envisionfit/models/clothing_item.dart';

class ClothingService {
  static const String _clothingKey = 'clothing_items';

  static Future<List<ClothingItem>> getAllClothing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? clothingJson = prefs.getString(_clothingKey);
      
      if (clothingJson != null) {
        final List<dynamic> decodedData = json.decode(clothingJson);
        return decodedData.map((item) {
          try {
            return ClothingItem.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            print('Error parsing clothing item: $e');
            return null;
          }
        }).where((item) => item != null).cast<ClothingItem>().toList();
      }
      
      // Return sample data if no saved data exists
      return _getSampleClothing();
    } catch (e) {
      print('Error loading clothing: $e');
      return _getSampleClothing();
    }
  }

  static Future<ClothingItem?> getClothingById(String id) async {
    final clothingList = await getAllClothing();
    try {
      return clothingList.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  static Future<List<ClothingItem>> getClothingByCategory(ClothingCategory category) async {
    final clothingList = await getAllClothing();
    return clothingList.where((item) => item.category == category).toList();
  }

  static Future<bool> saveClothingItem(ClothingItem item) async {
    try {
      final clothingList = await getAllClothing();
      
      // Remove existing item with same ID if exists
      clothingList.removeWhere((existingItem) => existingItem.id == item.id);
      
      // Add the new/updated item
      clothingList.add(item);
      
      return await _saveClothingList(clothingList);
    } catch (e) {
      print('Error saving clothing item: $e');
      return false;
    }
  }

  static Future<bool> deleteClothingItem(String id) async {
    try {
      final clothingList = await getAllClothing();
      clothingList.removeWhere((item) => item.id == id);
      return await _saveClothingList(clothingList);
    } catch (e) {
      print('Error deleting clothing item: $e');
      return false;
    }
  }

  static Future<List<ClothingItem>> searchClothing(String query) async {
    final clothingList = await getAllClothing();
    final lowerQuery = query.toLowerCase();
    
    return clothingList.where((item) =>
      item.name.toLowerCase().contains(lowerQuery) ||
      item.categoryName.toLowerCase().contains(lowerQuery) ||
      item.color.toLowerCase().contains(lowerQuery) ||
      (item.brand?.toLowerCase().contains(lowerQuery) ?? false)
    ).toList();
  }

  static Future<bool> _saveClothingList(List<ClothingItem> clothingList) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList = clothingList.map((item) => item.toJson()).toList();
      return await prefs.setString(_clothingKey, json.encode(jsonList));
    } catch (e) {
      print('Error saving clothing list: $e');
      return false;
    }
  }

  static List<ClothingItem> _getSampleClothing() {
    final now = DateTime.now();
    const defaultUserId = 'sample-user';
    return [
      ClothingItem(
        id: '1',
        userId: defaultUserId,
        name: 'Classic White Shirt',
        category: ClothingCategory.shirt,
        brand: 'StyleCorp',
        color: 'White',
        imagePath: 'assets/images/white_button_shirt_null_1762537685519.jpg',
        description: 'A timeless white button-down shirt perfect for any occasion',
        createdAt: now,
        updatedAt: now,
      ),
      ClothingItem(
        id: '2',
        userId: defaultUserId,
        name: 'Denim Jeans',
        category: ClothingCategory.pants,
        brand: 'DenimCo',
        color: 'Blue',
        imagePath: 'assets/images/blue_denim_jeans_null_1762537686437.jpg',
        description: 'Comfortable slim-fit denim jeans with modern styling',
        createdAt: now,
        updatedAt: now,
      ),
      ClothingItem(
        id: '3',
        userId: defaultUserId,
        name: 'Summer Floral Dress',
        category: ClothingCategory.dress,
        brand: 'FloralStyle',
        color: 'Pink',
        imagePath: 'assets/images/pink_floral_dress_null_1762537687380.jpg',
        description: 'Light and airy floral dress perfect for summer days',
        createdAt: now,
        updatedAt: now,
      ),
      ClothingItem(
        id: '4',
        userId: defaultUserId,
        name: 'Leather Jacket',
        category: ClothingCategory.jacket,
        brand: 'LeatherLux',
        color: 'Black',
        imagePath: 'assets/images/black_leather_jacket_null_1762537688491.jpg',
        description: 'Stylish genuine leather jacket with modern fit',
        createdAt: now,
        updatedAt: now,
      ),
      ClothingItem(
        id: '5',
        userId: defaultUserId,
        name: 'Casual Sneakers',
        category: ClothingCategory.shoes,
        brand: 'ComfortWalk',
        color: 'White',
        imagePath: 'assets/images/white_casual_sneakers_null_1762537690244.jpg',
        description: 'Comfortable white sneakers for everyday wear',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}