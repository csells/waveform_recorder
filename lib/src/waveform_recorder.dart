import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gap/gap.dart';
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

  @override
  void initState() {
    super.initState();

    widget.onRecordingStarted?.call();
    if (widget.onRecordingStopped != null) {
      widget.controller.addListener(_onRecordingChange);
    }

    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => setState(() {}),
    );
  }

  void _onRecordingChange() {
    assert(widget.onRecordingStopped != null);
    if (!widget.controller.isRecording) {
      _timer?.cancel();
      _timer = null;
      widget.onRecordingStopped?.call();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
              const Gap(8),
              Expanded(
                child: AnimatedWaveList(
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
