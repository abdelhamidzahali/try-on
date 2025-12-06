import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:http/http.dart' as http;

import 'package:envisionfit/services/save_result.dart';

Future<SaveResult> saveImageFromPathImpl(String imagePath, {String? filename}) async {
  try {
    Uint8List bytes;

    if (imagePath.startsWith('http')) {
      final res = await http.get(Uri.parse(imagePath));
      if (res.statusCode != 200) {
        return SaveResult.fail('Failed to download image (${res.statusCode})');
      }
      bytes = res.bodyBytes;
    } else if (imagePath.startsWith('data:')) {
      // data URL like data:image/png;base64,....
      final comma = imagePath.indexOf(',');
      if (comma == -1) return SaveResult.fail('Invalid data URL');
      final base64 = imagePath.substring(comma + 1);
      bytes = Uint8List.fromList(const Base64Decoder().convert(base64));
    } else {
      final file = File(imagePath);
      if (!await file.exists()) {
        return SaveResult.fail('Local file not found');
      }
      bytes = await file.readAsBytes();
    }

    final name = (filename ?? 'tryon_${DateTime.now().millisecondsSinceEpoch}').replaceAll('/', '_');
    final result = await ImageGallerySaver.saveImage(
      bytes,
      quality: 100,
      name: name,
    );

    final isSuccess = (result is Map) ? (result['isSuccess'] == true) : true;
    if (isSuccess) {
      return SaveResult.ok('Saved to Photos');
    }
    return SaveResult.fail('Save failed');
  } catch (e, st) {
    debugPrint('Save to gallery failed for $imagePath: $e');
    debugPrint('$st');
    return SaveResult.fail('Error: $e');
  }
}
