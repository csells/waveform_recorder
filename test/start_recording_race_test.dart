import 'dart:async';
import 'dart:io';

import 'package:cross_file_io/cross_file_io.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:record/record.dart';
import 'package:waveform_recorder/waveform_recorder.dart';

/// A [RecordPlatform] that lets a test hold `startRecording()` mid-flight.
///
/// [permissionGate] stands in for the real-world delay that opens the race
/// window: on macOS and iOS the OS permission prompt can leave
/// `hasPermission()` unresolved for as long as the user takes to answer it.
class FakeRecordPlatform extends RecordPlatform {
  /// When non-null, `hasPermission()` does not complete until the test
  /// completes this gate.
  Completer<bool>? permissionGate;

  final _stateController = StreamController<RecordState>.broadcast();

  /// Releases the state stream; call from `tearDown`.
  void close() => unawaited(_stateController.close());

  @override
  Future<void> create(String recorderId) async {}

  @override
  Future<bool> hasPermission(String recorderId, {bool request = true}) =>
      permissionGate?.future ?? Future.value(true);

  /// How many times the recorder has been started.
  int startCount = 0;

  @override
  Future<void> start(
    String recorderId,
    RecordConfig config, {
    required String path,
  }) async {
    startCount++;
  }

  @override
  Future<Stream<Uint8List>> startStream(
    String recorderId,
    RecordConfig config,
  ) async => const Stream<Uint8List>.empty();

  /// How many times the recorder has been stopped.
  int stopCount = 0;

  /// The path `stop()` reports for the recording. Empty by default, which
  /// keeps the controller out of its file-handling path.
  String stopPath = '';

  @override
  Future<String?> stop(String recorderId) async {
    stopCount++;
    return stopPath;
  }

  @override
  Future<void> pause(String recorderId) async {}

  @override
  Future<void> resume(String recorderId) async {}

  @override
  Future<bool> isRecording(String recorderId) async => true;

  @override
  Future<bool> isPaused(String recorderId) async => false;

  @override
  Future<void> dispose(String recorderId) async {}

  @override
  Future<Amplitude> getAmplitude(String recorderId) async =>
      Amplitude(current: -20, max: 0);

  @override
  Future<bool> isEncoderSupported(
    String recorderId,
    AudioEncoder encoder,
  ) async => true;

  @override
  Future<List<InputDevice>> listInputDevices(String recorderId) async => [];

  @override
  Future<void> cancel(String recorderId) async {}

  @override
  Stream<RecordState> onStateChanged(String recorderId) =>
      _stateController.stream;

  @override
  void setOnConfigChanged(
    String recorderId,
    void Function(RecordConfig config)? handler,
  ) {}
}

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final originalPlatform = RecordPlatform.instance;
  late FakeRecordPlatform platform;

  /// The controller disposes its recorder without awaiting it, so give those
  /// futures a chance to land while the fake platform is still installed.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    platform = FakeRecordPlatform();
    RecordPlatform.instance = platform;

    // The controller asks path_provider for a temp directory; the fake
    // recorder never writes to it.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _pathProviderChannel,
          (call) async => Directory.systemTemp.path,
        );
  });

  tearDown(() {
    platform.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProviderChannel, null);
  });

  tearDownAll(() => RecordPlatform.instance = originalPlatform);

  test('isRecording stays false until the amplitude stream is ready', () async {
    final controller = WaveformRecorderController();

    platform.permissionGate = Completer<bool>();
    final starting = controller.startRecording();

    // startRecording() has begun but is parked on the permission prompt.
    expect(
      controller.isRecording,
      isFalse,
      reason:
          'isRecording must not claim to be recording before the '
          'amplitude stream exists',
    );
    expect(controller.isStarting, isTrue);

    platform.permissionGate!.complete(true);
    await starting;

    expect(controller.isRecording, isTrue);
    expect(controller.isStarting, isFalse);

    await controller.stopRecording();
    controller.dispose();
    await settle();
  });

  test(
    'amplitudeStream never throws while startRecording is in flight',
    () async {
      final controller = WaveformRecorderController();

      // Before starting at all.
      expect(() => controller.amplitudeStream, returnsNormally);

      platform.permissionGate = Completer<bool>();
      final starting = controller.startRecording();

      // This is the throw reported in issue #12: isRecording said `true`, so
      // callers read amplitudeStream, and the getter blew up.
      expect(() => controller.amplitudeStream, returnsNormally);

      platform.permissionGate!.complete(true);
      await starting;

      expect(() => controller.amplitudeStream, returnsNormally);

      await controller.stopRecording();

      // And after stopping.
      expect(() => controller.amplitudeStream, returnsNormally);

      controller.dispose();
      await settle();
    },
  );

  test('a failed startRecording leaves the controller reusable', () async {
    final controller = WaveformRecorderController();

    platform.permissionGate = Completer<bool>();
    final starting = controller.startRecording();

    // let the start actually reach the permission prompt before denying it
    await settle();
    expect(controller.isStarting, isTrue);
    platform.permissionGate!.completeError(Exception('permission denied'));

    await expectLater(starting, throwsException);

    expect(controller.isRecording, isFalse);
    expect(controller.isStarting, isFalse);
    expect(controller.startTime, isNull);

    // The user taps the mic again; this must not report 'Already recording'.
    platform.permissionGate = null;
    await controller.startRecording();
    expect(controller.isRecording, isTrue);

    await controller.stopRecording();
    controller.dispose();
    await settle();
  });

  test(
    'a denied permission fails the start without starting the recorder',
    () async {
      final controller = WaveformRecorderController();
      var notifications = 0;
      controller.addListener(() => notifications++);

      platform.permissionGate = Completer<bool>();
      final starting = controller.startRecording();
      await settle();
      platform.permissionGate!.complete(false);

      await expectLater(starting, throwsException);

      expect(platform.startCount, 0);
      expect(controller.isRecording, isFalse);
      expect(controller.isStarting, isFalse);
      expect(controller.startTime, isNull);
      // Listeners hear about the failed start, so a UI showing isStarting
      // goes back to idle.
      expect(notifications, 2);

      controller.dispose();
      await settle();
    },
  );

  test('overlapping startRecording calls are still rejected', () async {
    final controller = WaveformRecorderController();

    platform.permissionGate = Completer<bool>();
    final starting = controller.startRecording();

    await expectLater(controller.startRecording(), throwsException);

    platform.permissionGate!.complete(true);
    await starting;

    await controller.stopRecording();
    controller.dispose();
    await settle();
  });

  test('disposing during startRecording releases the recorder', () async {
    final controller = WaveformRecorderController();

    platform.permissionGate = Completer<bool>();
    final starting = controller.startRecording();
    await settle();

    // the user navigates away while the permission prompt is still up
    controller.dispose();

    platform.permissionGate!.complete(true);
    await starting;
    await settle();

    expect(controller.isRecording, isFalse);
    expect(controller.isStarting, isFalse);
    expect(
      platform.stopCount,
      1,
      reason: 'the abandoned recorder must be stopped, not left running',
    );
  });

  testWidgets(
    'WaveformRecorder mounts safely while startRecording is in flight',
    (tester) async {
      final controller = WaveformRecorderController();

      platform.permissionGate = Completer<bool>();
      final starting = controller.startRecording();

      // The example app mounts WaveformRecorder from a parent rebuild; doing so
      // during the start window used to throw Exception('Not recording') out of
      // build().
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WaveformRecorder(height: 48, controller: controller),
        ),
      );

      expect(tester.takeException(), isNull);

      // The widget's 250ms rebuild timer keeps hitting build() during the
      // window.
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      platform.permissionGate!.complete(true);
      await tester.pump();
      await starting;
      await tester.pump();
      expect(tester.takeException(), isNull);

      await controller.stopRecording();
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.pump();
    },
  );

  testWidgets('onRecordingStopped fires once, on the stop transition', (
    tester,
  ) async {
    final controller = WaveformRecorderController();
    var stoppedCount = 0;

    // Mounted before recording ever starts, which is now a supported usage.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WaveformRecorder(
          height: 48,
          controller: controller,
          onRecordingStopped: () => stoppedCount++,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(stoppedCount, 0, reason: 'nothing has been recorded yet');

    await controller.startRecording();
    await tester.pump();
    expect(stoppedCount, 0, reason: 'starting is not stopping');

    await controller.stopRecording();
    await tester.pump();
    expect(stoppedCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.pump();
  });

  test('a stopped recording is exposed as a file-system XFile', () async {
    final dir = await Directory.systemTemp.createTemp('waveform_recorder_');
    addTearDown(() => dir.delete(recursive: true));
    final recording = File('${dir.path}/audio-1.m4a');
    await recording.writeAsBytes([1, 2, 3]);
    platform.stopPath = recording.path;

    // plugin implementations aren't registered under `flutter test`
    CrossFileIO.registerWith();

    final controller = WaveformRecorderController();
    expect(controller.file, isNull);
    expect(controller.fileName, isNull);
    expect(controller.mimeType, isNull);

    await controller.startRecording();
    await controller.stopRecording();

    final file = controller.file;
    expect(file, isA<FileSystemXFile>());
    expect((file! as FileSystemXFile).path, recording.path);
    expect(await file.length(), 3);
    expect(controller.fileName, 'audio-1.m4a');
    expect(controller.mimeType, 'audio/mp4');

    controller.clear();
    expect(controller.file, isNull);
    expect(controller.fileName, isNull);
    expect(controller.mimeType, isNull);

    controller.dispose();
    await settle();
  });
}
