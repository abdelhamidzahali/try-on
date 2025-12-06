import 'dart:convert';
import 'dart:typed_data';

import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:envisionfit/services/save_result.dart';

Future<SaveResult> saveImageFromPathImpl(String imagePath, {String? filename}) async {
  try {
    Uint8List bytes;
    String ext = 'jpg';
    String mime = 'image/jpeg';

    if (imagePath.startsWith('data:')) {
      final headerEnd = imagePath.indexOf(',');
      if (headerEnd == -1) return SaveResult.fail('Invalid data URL');
      final header = imagePath.substring(0, headerEnd);
      if (header.contains('image/png')) { ext = 'png'; mime = 'image/png'; }
      final b64 = imagePath.substring(headerEnd + 1);
      bytes = Uint8List.fromList(const Base64Decoder().convert(b64));
    } else if (imagePath.startsWith('http')) {
      final uri = Uri.parse(imagePath);
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        return SaveResult.fail('Failed to fetch image (${res.statusCode})');
      }
      final contentType = res.headers['content-type'] ?? '';
      if (contentType.contains('png')) { ext = 'png'; mime = 'image/png'; }
      else if (contentType.contains('webp')) { ext = 'webp'; mime = 'image/webp'; }
      bytes = res.bodyBytes;
    } else {
      // On web local file paths are not accessible; user likely wants the rendered image URL.
      return SaveResult.fail('Unsupported image path on web');
    }

    final name = (filename ?? 'tryon_${DateTime.now().millisecondsSinceEpoch}').replaceAll('/', '_');
    final blob = html.Blob([bytes], mime);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)..download = '$name.$ext';
    anchor.click();
    html.Url.revokeObjectUrl(url);
    return SaveResult.ok('Downloaded');
  } catch (e, st) {
    debugPrint('Web download failed for $imagePath: $e');
    debugPrint('$st');
    return SaveResult.fail('Error: $e');
  }
}
