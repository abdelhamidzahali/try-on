import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Encodes a solid-colour JPEG of the given size and grey level (0..255).
Uint8List solidJpeg({required int width, required int height, int grey = 200}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(grey, grey, grey));
  return Uint8List.fromList(img.encodeJpg(image));
}

/// Writes [bytes] to a fresh file under a temp directory and returns it.
Future<File> writeTempImage(Uint8List bytes, {String name = 'photo.jpg'}) async {
  final dir = await Directory.systemTemp.createTemp('tryon_test_');
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes);
  return file;
}
