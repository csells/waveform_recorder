import 'package:audioplayers/audioplayers.dart';
import 'package:waveform_recorder/waveform_recorder.dart';
import 'package:web/web.dart' as web;

class PlatformHelper {
  // on the web the recording is a blob URL
  static Source audioSource(XFile file, {String? mimeType}) =>
      UrlSource(file.uri, mimeType: mimeType);

  static Future<void> deleteFile(XFile file) async {}

  static Future<void> downloadFile(XFile file, String name) async {
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = file.uri
      ..style.display = 'none'
      ..download = name;
    web.document.body!.appendChild(anchor);
    anchor.click();
    web.document.body!.removeChild(anchor);
  }
}
