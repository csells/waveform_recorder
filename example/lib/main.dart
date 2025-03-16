import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
// import 'package:waveform_recorder/src/platform_helper/platform_helper.dart';
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
                      if(_waveController.isRecording)
                      IconButton(
                        icon: Icon(
                          _waveController.isPaused
                              ? Icons.play_arrow
                              : Icons.pause,
                        ),
                        onPressed: _togglePauseRecording
                      ),
                      IconButton(
                        icon: Icon(
                          _waveController.isRecording ? Icons.stop : Icons.mic,
                        ),
                        onPressed: _toggleRecording,
                      ),
                      if (_waveController.isRecording)
                        IconButton(
                          icon: const Icon(
                            Icons.delete,
                          ),
                          onPressed: _cancelRecording,
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

  Future<void> _cancelRecording() async {
    await _waveController.cancelRecording();
    _textController.text = 'canceled';
  }

  Future<void> _togglePauseRecording() => switch (_waveController.isPaused) {
    true => _waveController.resumeRecording(),
    false => _waveController.pauseRecording(),
  };


  Future<void> _onRecordingStopped() async {
    final file = _waveController.file;
    if (file == null) return;

    _textController.text = ''
        '${file.name}: '
        '${_waveController.length.inMilliseconds / 1000} seconds';

    debugPrint('XFile properties:');
    debugPrint('  path: ${file.path}');
    debugPrint('  name: ${file.name}');
    debugPrint('  mimeType: ${file.mimeType}');

    // download file from web to ensure it's a playable set of bytes
    // assert(await () async {
    //   await PlatformHelper.downloadFile(file);
    //   return true;
    // }());
  }

  Future<void> _playRecording() async {
    final file = _waveController.file;
    if (file == null) return;
    final source = kIsWeb ? UrlSource(file.path) : DeviceFileSource(file.path);
    await AudioPlayer().play(source);
  }
}
