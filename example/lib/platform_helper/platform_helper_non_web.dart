import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PlatformHelper {
  static Source audioSource(XFile file) => DeviceFileSource(
        file.path,
        mimeType: file.mimeType,
      );

  static Future<void> deleteFile(XFile file) => File(file.path).delete();

  static Future<void> downloadFile(XFile file) async {
    final dir = (await getDownloadsDirectory())!;
    final path = p.join(dir.path, file.name);
    await File(path).writeAsBytes(await file.readAsBytes());
  }
}
