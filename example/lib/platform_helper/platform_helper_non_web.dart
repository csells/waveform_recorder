import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:waveform_recorder/waveform_recorder.dart';

class PlatformHelper {
  // on native platforms the recording is a file on disk
  static String _path(XFile file) => (file as FileSystemXFile).path;

  static Source audioSource(XFile file, {String? mimeType}) =>
      DeviceFileSource(_path(file), mimeType: mimeType);

  static Future<void> deleteFile(XFile file) => File(_path(file)).delete();

  static Future<void> downloadFile(XFile file, String name) async {
    final dir = (await getDownloadsDirectory())!;
    await File(_path(file)).copy(p.join(dir.path, name));
  }
}
