import 'package:envisionfit/services/save_result.dart';

// Conditional implementation: use HTML version on web, IO version otherwise
import 'download_saver_io.dart' if (dart.library.html) 'download_saver_web.dart';

class DownloadSaver {
  static Future<SaveResult> saveImageFromPath(String imagePath, {String? filename}) {
    return saveImageFromPathImpl(imagePath, filename: filename);
  }
}
