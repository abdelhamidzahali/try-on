import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:envisionfit/navigation/app_navigator.dart';
import 'package:http/http.dart' as http;

class ImageService {
  static final ImagePicker _picker = ImagePicker();

  static Future<bool> requestPermissions() async {
    // On web, permissions are handled by the browser; assume granted.
    if (kIsWeb) return true;

    final cameraStatus = await Permission.camera.request();
    final photosStatus = await Permission.photos.request();
    return cameraStatus.isGranted && photosStatus.isGranted;
  }

  static Future<File?> pickImageFromCamera() async {
    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        throw Exception('Camera permissions not granted');
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        if (kIsWeb) {
          // Convert to data URL for web-safe storage and display
          final bytes = await image.readAsBytes();
          final b64 = base64Encode(bytes);
          final mime = _inferMimeFromName(image.name) ?? 'image/jpeg';
          return File('data:$mime;base64,$b64');
        }
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image from camera: $e');
      return null;
    }
  }

  static Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          final b64 = base64Encode(bytes);
          final mime = _inferMimeFromName(image.name) ?? 'image/jpeg';
          return File('data:$mime;base64,$b64');
        }
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  static Future<File?> cropImage(File imageFile) async {
    // Cropper removed for web stability; return original image.
    // You can reintroduce platform-specific cropping later if needed.
    return imageFile;
  }

  static Future<File?> saveImageToAppDirectory(File imageFile, String fileName) async {
    try {
      // On web, skip filesystem copy; the File.path may be a data URL or blob
      if (kIsWeb) {
        return imageFile;
      }

      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final savedFile = File('${imagesDir.path}/$fileName');
      return await imageFile.copy(savedFile.path);
    } catch (e) {
      // Fallback: if anything fails (e.g., no path_provider on current platform),
      // just return the original reference so the flow can continue.
      print('Error saving image: $e');
      try {
        if (kIsWeb) return imageFile;
        // As a last resort, convert to in-memory data URL to keep UI functional.
        final bytes = await imageFile.readAsBytes();
        final b64 = base64Encode(bytes);
        final mime = _inferMimeFromName(fileName) ?? 'image/jpeg';
        return File('data:$mime;base64,$b64');
      } catch (_) {
        return null;
      }
    }
  }

  /// Saves raw image bytes to a file in the app directory (mobile/desktop)
  /// or returns a data URL wrapped in a File on Web for consistent usage.
  static Future<File?> saveBytesToImageFile(
    Uint8List bytes,
    String fileName, {
    String mimeType = 'image/png',
  }) async {
    try {
      if (kIsWeb) {
        final b64 = base64Encode(bytes);
        return File('data:$mimeType;base64,$b64');
      }

      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final savedFile = File('${imagesDir.path}/$fileName');
      await savedFile.writeAsBytes(bytes, flush: true);
      return savedFile;
    } catch (e) {
      print('Error saving bytes to image file: $e');
      // Fallback: return a data URL File so the UI can still display it
      try {
        final b64 = base64Encode(bytes);
        return File('data:$mimeType;base64,$b64');
      } catch (_) {
        return null;
      }
    }
  }

  static Future<Uint8List?> fileToBytes(File imageFile) async {
    try {
      if (kIsWeb) {
        final p = imageFile.path;
        // Handle data URL
        if (p.startsWith('data:')) {
          final comma = p.indexOf(',');
          if (comma != -1) {
            final b64 = p.substring(comma + 1);
            return base64Decode(b64);
          }
        }
        // Fetch via HTTP/XHR for blob/http/relative asset paths
        final uri = Uri.parse(p);
        final res = await http.get(uri);
        if (res.statusCode == 200) {
          return res.bodyBytes;
        }
        throw Exception('Failed to load image bytes (${res.statusCode})');
      }
      return await imageFile.readAsBytes();
    } catch (e) {
      print('Error reading file bytes: $e');
      return null;
    }
  }

  /// Loads an asset image and writes it to the app documents directory
  /// returning a File reference that points to the written image.
  /// Useful when you need a File for APIs that don't accept asset paths.
  static Future<File?> assetToFile(String assetPath, {String? fileName}) async {
    try {
      final bytes = await rootBundle.load(assetPath);

      if (kIsWeb) {
        // Return a data URL wrapped in File for consistent typing
        final list = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
        final b64 = base64Encode(list);
        final mime = _inferMimeFromName(assetPath) ?? 'image/png';
        return File('data:$mime;base64,$b64');
      }

      final directory = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${directory.path}/images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final resolvedName = fileName ?? generateFileName('asset');
      final file = File('${imagesDir.path}/$resolvedName');
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      return file;
    } catch (e) {
      print('Error converting asset to file: $e');
      return null;
    }
  }

  static Future<bool> deleteImage(String imagePath) async {
    try {
      if (kIsWeb) {
        // Nothing to delete for data URLs/blob references
        return true;
      }
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  static String generateFileName(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_$timestamp.jpg';
  }

  static String? _inferMimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return null;
  }
}