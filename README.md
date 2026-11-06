The [waveform_recorder package](https://pub.dev/packages/waveform_recorder)
provides a widget to show a waveform as an audio stream is being recorded in the
style of recent AI chat packages.

![Screenshot of waveform_recorder in
action](https://raw.githubusercontent.com/csells/waveform_recorder/refs/heads/main/readme/screenshot.png)

## Setup

For this package to work, you'll need to set up [the underlying `record`
package](https://pub.dev/packages/record) according to [the setup and permission
instructions](https://pub.dev/packages/record#setup-permissions-and-others).

## Usage

The main entry point for this package is the `WaveformRecorder` widget, which
requires an instance of the `WaveformRecorderController` to start/stop
recording. Here's an example of using the recorder to record audio and then
allowing the user to play it back:

```dart
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:waveform_recorder/waveform_recorder.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _textController = TextEditingController();
  final _waveController = WaveformRecorderController();

  @override
  void dispose() {
    _textController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('WaveForm Example')),
          body: ListenableBuilder(
            listenable: _waveController,
            builder: (context, _) => Column(
              children: [
                Expanded(
                  child: Center(
                    child: OutlinedButton(
                      onPressed: !_waveController.isRecording &&
                              _waveController.file != null
                          ? _playRecording
                          : null,
                      child: const Text('Play'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _waveController.isRecording
                              ? WaveformRecorder(
                                  height: 48,
                                  controller: _waveController,
                                  onRecordingStopped: _onRecordingStopped,
                                )
                              : TextField(
                                  controller: _textController,
                                  maxLines: 1,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const Gap(8),
                      IconButton(
                        icon: Icon(
                          _waveController.isRecording ? Icons.stop : Icons.mic,
                        ),
                        // starting can block on an OS permission prompt
                        onPressed: _waveController.isStarting
                            ? null
                            : _toggleRecording,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _toggleRecording() => switch (_waveController.isRecording) {
        true => _waveController.stopRecording(),
        false => _waveController.startRecording(),
      };

  Future<void> _onRecordingStopped() async {
    final file = _waveController.file;
    if (file == null) return;

    _textController.text = ''
        '${_waveController.fileName}: '
        '${_waveController.length.inMilliseconds / 1000} seconds';

    debugPrint('Recording properties:');
    debugPrint('  uri: ${file.uri}');
    debugPrint('  fileName: ${_waveController.fileName}');
    debugPrint('  mimeType: ${_waveController.mimeType}');
  }

  Future<void> _playRecording() async {
    final file = _waveController.file;
    if (file == null) return;
    final source = file is FileSystemXFile
        ? DeviceFileSource(file.path)
        : UrlSource(file.uri);
    await AudioPlayer().play(source);
  }
}
```

### Usage Considerations

`WaveformRecorderController.file` is an `XFile` from [the cross_file
package](https://pub.dev/packages/cross_file); waveform_recorder re-exports
`XFile`, `FileSystemXFile` and `ScopedStorageXFile` so you don't need to depend on
cross_file yourself.

On every platform except the web, the recording is a temporary file on disk and
`file` is a `FileSystemXFile`; it's your app's responsibility to remove this
temp file when it's done with it. On the web, the recording is a blob URL and
`file` is a `ScopedStorageXFile` whose `uri` is that URL. Use the controller's
`fileName` and `mimeType` for a display/download name and content type, e.g.

```dart
  Future<void> _deleteRecording() async {
    final file = _waveController.file;
    if (file is FileSystemXFile) await File(file.path).delete();
  }
```

### Upgrading to 2.0

Version 2.0 moves to cross_file 0.4, whose `XFile` no longer has `path`,
`mimeType` or a synchronous `name`:

- `file.path` → `(file as FileSystemXFile).path` on native platforms, or
  `file.uri` (the blob URL) on the web
- `file.name` → `controller.fileName`
- `file.mimeType` → `controller.mimeType`

It also requires Dart 3.11 / Flutter 3.41 or later.

## Feedback

Your feedback via [issues](https://github.com/csells/waveform_recorder/issues)
or [PRs](https://github.com/csells/waveform_recorder/pulls) is welcome!