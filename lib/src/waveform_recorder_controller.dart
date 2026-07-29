import 'dart:async';

// import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as ph; // path helper
import 'package:record/record.dart';
import 'package:waveform_flutter/waveform_flutter.dart' as waveform;

import 'platform_helper/platform_helper.dart';

/// A controller for managing audio recording and waveform generation.
class WaveformRecorderController extends ChangeNotifier {
  /// Creates a new instance of [WaveformRecorderController].
  ///
  ///
  /// [interval] determines how often amplitude data is emitted (default is
  /// 250ms). [encoder] specifies the audio encoding format (default is
  /// platform-dependent). [config] sets other settings like bit rate, sample
  /// rate, etc.
  WaveformRecorderController({
    this.interval = const Duration(milliseconds: 250),
    @Deprecated('Use config instead') AudioEncoder? encoder,
    RecordConfig? config,
  }) : config = RecordConfig(
          encoder: encoder ??
              config?.encoder ??
              (kIsWeb ? AudioEncoder.wav : AudioEncoder.aacLc),
          numChannels: config?.numChannels ?? 1,
          bitRate: config?.bitRate ?? 128000,
          sampleRate: config?.sampleRate ?? 44100,
          device: config?.device,
          autoGain: config?.autoGain ?? false,
          echoCancel: config?.echoCancel ?? false,
          noiseSuppress: config?.noiseSuppress ?? false,
          androidConfig: config?.androidConfig ?? const AndroidRecordConfig(),
          audioInterruption:
              config?.audioInterruption ?? AudioInterruptionMode.pause,
          iosConfig: config?.iosConfig ?? const IosRecordConfig(),
        );

  /// The interval at which amplitude data is emitted during recording.
  ///
  /// This determines how frequently the waveform is updated. Default is 250ms.
  final Duration interval;

  /// The audio config used for recording.
  ///
  /// Encode default is platform-dependent: WAV for web, AAC-LC for other
  /// platforms.
  final RecordConfig config;

  Stream<waveform.Amplitude>? _amplitudeStream;
  AudioRecorder? _audioRecorder;
  XFile? _file;
  var _length = Duration.zero;
  var _starting = false;
  var _disposed = false;
  DateTime? _startTime;

  ///This keeps track of the time elapsed since recording was started.
  final Stopwatch _stopwatch = Stopwatch();

  /// Returns the elapsed time since the recording started,
  /// excluding any paused time.
  Duration get timeElapsed => _stopwatch.elapsed;

  ///Indicates whether audio recording is currently paused or not.
  bool get isPaused => !_stopwatch.isRunning;

  /// Indicates whether audio recording is currently in progress.
  ///
  /// This is only true once the recorder is live and [amplitudeStream] is
  /// wired up. Starting is asynchronous, so there is a window after
  /// [startRecording] is called during which this is still false; see
  /// [isStarting].
  bool get isRecording => _audioRecorder != null;

  /// Indicates whether a [startRecording] call is still in flight.
  ///
  /// Starting a recording is asynchronous and can block for a long time on an
  /// OS permission prompt. During that window both this and [isRecording] tell
  /// the truth: [isStarting] is true, [isRecording] is false. Use this to
  /// disable a record button or show a spinner while the recorder spins up.
  bool get isStarting => _starting;

  /// Provides a stream of amplitude data for generating the waveform.
  ///
  /// Returns an empty stream when not recording, so this is always safe to
  /// read — including from a `build` method, where a throw would take down the
  /// app.
  Stream<waveform.Amplitude> get amplitudeStream =>
      _amplitudeStream ?? const Stream<waveform.Amplitude>.empty();

  /// The recorded audio file.
  ///
  /// This property returns the [XFile] containing the recorded audio data. It
  /// will be null if no recording has been made or if the recording process
  /// hasn't completed.
  XFile? get file => _file;

  /// The duration of the recorded audio.
  Duration get length => _length;

  /// The start time of the current or last recording session.
  DateTime? get startTime => _startTime;

  @override
  void dispose() {
    _disposed = true;
    _amplitudeStream = null;
    unawaited(_audioRecorder?.dispose());
    _audioRecorder = null;
    _file = null;
    _length = Duration.zero;
    _startTime = null;
    _stopwatch
      ..stop()
      ..reset();
    super.dispose();
  }

  /// Starts a new audio recording session.
  ///
  /// Throws an exception if already recording, or if a previous
  /// [startRecording] call is still in flight.
  ///
  /// The session is published in a single step once the recorder is actually
  /// live: until then [isRecording] stays false and [amplitudeStream] stays
  /// empty, so it is safe to render from this controller while a start is
  /// still in flight. If starting fails, the controller is left idle and ready
  /// to try again.
  Future<void> startRecording() async {
    if (_starting || _audioRecorder != null) {
      throw Exception('Already recording');
    }
    assert(_amplitudeStream == null);
    assert(_startTime == null);

    _starting = true;
    _file = null;
    _length = Duration.zero;

    // Announce the pending start on a microtask so that callers may start
    // recording from initState or a build callback without notifying
    // listeners mid-build.
    await Future<void>.microtask(() {
      if (!_disposed) notifyListeners();
    });

    final recorder = AudioRecorder();
    try {
      // request permissions (needed for Android)
      await recorder.hasPermission();

      // start the recording into a temp file (or in memory on the web)
      final ext = _extFor(config.encoder);
      final path = await PlatformHelper.getTempPath(ext);
      await recorder.start(config, path: path);
    } on Object {
      // leave the controller idle so the caller can retry
      _starting = false;
      unawaited(recorder.dispose());
      if (!_disposed) notifyListeners();
      rethrow;
    }

    // The controller can be disposed while the start is in flight — the user
    // navigates away while the permission prompt is still up, say. The
    // recorder is live by now, so let go of it rather than leaving the
    // microphone hot.
    if (_disposed) {
      _starting = false;
      unawaited(_discard(recorder));
      return;
    }

    // Publish the session in one step. Assigning the recorder before its
    // amplitude stream exists is what made isRecording lie and amplitudeStream
    // throw out of build(); see issue #12.
    _startTime = DateTime.now();
    _audioRecorder = recorder;

    // map the amplitude types as they stream in
    _amplitudeStream = recorder
        .onAmplitudeChanged(interval)
        .map(
          (a) => waveform.Amplitude(current: a.current, max: a.max),
        )
        .asBroadcastStream(); // allows multiple listeners

    _stopwatch
      ..reset()
      ..start();
    _starting = false;

    notifyListeners();
  }

  /// Stops the current audio recording session.
  ///
  /// Throws an exception if not currently recording.
  Future<void> stopRecording() async {
    if (_audioRecorder == null) throw Exception('Not recording');
    assert(_file == null);
    assert(_length == Duration.zero);

    final recorder = _audioRecorder!;
    try {
      final path = await recorder.stop() ?? '';
      if (path.isNotEmpty) {
        await PlatformHelper.waitForTempAudioFile(path);
        _file = _fileFor(config.encoder, path);
        _length = _stopwatch.elapsed;
      }
    } finally {
      unawaited(recorder.dispose());
      _audioRecorder = null;
      _amplitudeStream = null;
      _startTime = null;
      _stopwatch
        ..stop()
        ..reset();

      notifyListeners();
    }
  }

  /// Pauses the current audio recording session if it is recording.
  ///
  /// Throws an exception if the recording has not been started yet.
  Future<void> pauseRecording() async {
    if (_audioRecorder == null) throw Exception('Recording not started');
    assert(_file == null);
    assert(_length == Duration.zero);

    if (await _audioRecorder!.isRecording()) {
      await _audioRecorder!.pause();
      _stopwatch.stop();
    }

    notifyListeners();
  }

  /// Resumes the current audio recording session if it was paused.
  ///
  /// Throws an exception if the recording has not been started yet.
  Future<void> resumeRecording() async {
    if (_audioRecorder == null) throw Exception('Recording not started');
    assert(_file == null);
    assert(_length == Duration.zero);

    if (await _audioRecorder!.isPaused()) {
      await _audioRecorder!.resume();
      _stopwatch.start();
    }

    notifyListeners();
  }

  /// Cancels the current audio recording session.
  ///
  /// This method stops the recording, deletes any temporary recording files,
  /// and resets the controller state. It does not save the recorded audio.
  ///
  /// Throws an exception if not currently recording
  Future<void> cancelRecording() async {
    if (_audioRecorder == null) throw Exception('Not recording');
    assert(_file == null);
    assert(_length == Duration.zero);

    // stop the recording, deleting the temp file (if there is one)
    final path = await _audioRecorder!.stop() ?? '';
    await PlatformHelper.deleteTempAudioFile(path);

    // Clean up resources
    unawaited(_audioRecorder!.dispose());
    _audioRecorder = null;
    _amplitudeStream = null;
    _startTime = null;
    _stopwatch
      ..stop()
      ..reset();

    notifyListeners();
  }

  /// Stops and releases a recorder that nobody is going to listen to,
  /// discarding whatever it captured.
  Future<void> _discard(AudioRecorder recorder) async {
    try {
      final path = await recorder.stop() ?? '';
      await PlatformHelper.deleteTempAudioFile(path);
    } on Exception catch (e) {
      debugPrint('Error discarding abandoned recording: $e');
    } finally {
      await recorder.dispose();
    }
  }

  XFile _fileFor(AudioEncoder encoder, String path) {
    final ext = _extFor(encoder);
    final mimetype = _mimeTypeFor(encoder);
    final name = kIsWeb ? 'audio.$ext' : ph.basename(path);
    return XFile(path, name: name, mimeType: mimetype);
  }

  String _extFor(AudioEncoder encoder) => switch (encoder) {
        AudioEncoder.aacLc ||
        AudioEncoder.aacEld ||
        AudioEncoder.aacHe =>
          'm4a',
        AudioEncoder.amrNb || AudioEncoder.amrWb => '3gp',
        AudioEncoder.opus => 'opus',
        AudioEncoder.flac => 'flac',
        AudioEncoder.wav => 'wav',
        AudioEncoder.pcm16bits => 'pcm',
      };

  String _mimeTypeFor(AudioEncoder encoder) => switch (encoder) {
        AudioEncoder.aacLc ||
        AudioEncoder.aacEld ||
        AudioEncoder.aacHe ||
        AudioEncoder.opus =>
          'audio/mp4',
        AudioEncoder.amrNb || AudioEncoder.amrWb => 'audio/3gpp',
        AudioEncoder.flac => 'audio/flac',
        AudioEncoder.wav => 'audio/wav',
        AudioEncoder.pcm16bits => 'audio/pcm',
      };

  /// Clears the current recording state.
  ///
  /// After calling this method, the controller will be in the same state
  /// as when it was first created, ready for a new recording.
  void clear() {
    _stopwatch.stop();
    unawaited(_audioRecorder?.dispose());
    _file = null;
    _length = Duration.zero;
    _startTime = null;
    _amplitudeStream = null;
    _audioRecorder = null;
    notifyListeners();
  }
}
