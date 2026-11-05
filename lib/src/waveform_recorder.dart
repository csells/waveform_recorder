import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:waveform_flutter/waveform_flutter.dart';

import 'waveform_recorder_controller.dart';

/// A widget that displays a waveform visualization of audio recording.
class WaveformRecorder extends StatefulWidget {
  /// Creates a WaveformRecorder widget.
  ///
  /// The [height] and [controller] parameters are required.
  const WaveformRecorder({
    required this.height,
    required this.controller,
    this.onRecordingStarted,
    this.onRecordingStopped,
    this.waveColor = const Color(0xFF000000), // Default to black
    this.durationTextStyle =
        const TextStyle(color: Color(0xFF000000)), // Default to black
    super.key,
  });

  /// The height of the waveform visualization.
  final double height;

  /// The controller for managing the audio recording and waveform generation.
  final WaveformRecorderController controller;

  /// A callback function that is called when recording starts.
  final Function()? onRecordingStarted;

  /// A callback function that is called when recording ends.
  final Function()? onRecordingStopped;

  /// The color of the waveform bars.
  final Color waveColor;

  /// The text style for the duration text.
  final TextStyle durationTextStyle;

  @override
  State<WaveformRecorder> createState() => _WaveformRecorderState();
}

class _WaveformRecorderState extends State<WaveformRecorder> {
  Timer? _timer;

  /// Tracks the controller's last observed state so that recording changes are
  /// handled as transitions. The controller notifies for starting, pausing and
  /// resuming too, and only a recording -> not-recording edge means "stopped".
  late bool _wasRecording;

  @override
  void initState() {
    super.initState();

    _wasRecording = widget.controller.isRecording;
    widget.controller.addListener(_onRecordingChange);
    widget.onRecordingStarted?.call();

    if (_wasRecording) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _onRecordingChange() {
    final isRecording = widget.controller.isRecording;
    if (isRecording == _wasRecording) return;
    _wasRecording = isRecording;

    if (isRecording) {
      _startTimer();
    } else {
      _stopTimer();
      widget.onRecordingStopped?.call();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    widget.controller.removeListener(_onRecordingChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _elapsedTime,
                  style: widget.durationTextStyle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedWaveList(
                  // safe in any controller state: empty until recording starts
                  stream: widget.controller.amplitudeStream,
                  barBuilder: (animation, amplitude) => WaveFormBar(
                    animation: animation,
                    amplitude: amplitude,
                    color: widget.waveColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  String get _elapsedTime {
    final elapsed = widget.controller.timeElapsed;
    return ''
        '${elapsed.inMinutes.toString().padLeft(2, '0')}:'
        '${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
  }
}
