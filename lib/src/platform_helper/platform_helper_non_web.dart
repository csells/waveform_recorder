import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A helper class for platform-specific operations: non-web
class PlatformHelper {
  /// Generates a temporary file path for audio recording.
  ///
  /// This method creates a unique file path in the temporary directory for
  /// storing audio recordings.
  ///
  /// [ext] is the file extension for the audio file (e.g., 'm4a', 'wav').
  ///
  /// Returns a [Future] that completes with the generated file path as a
  /// [String].
  static Future<String> getTempPath(String ext) async {
    final dir = await getTemporaryDirectory();
    return p.join(
      dir.path,
      'audio-${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
  }

  /// Downloads the given XFile as an audio file in the browser to the user's
  /// Downloads directory
  ///
  /// [file] is the XFile to be downloaded.
  static Future<void> downloadFile(XFile file) async {
    final dir = (await getDownloadsDirectory())!;
    final path = p.join(dir.path, file.name);
    await File(path).writeAsBytes(await file.readAsBytes());
  }
}
