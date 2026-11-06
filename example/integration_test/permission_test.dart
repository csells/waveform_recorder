// On-device tests for starting a recording with the microphone permission
// denied or granted. See README.md in this directory for how to put each
// platform into the right permission state and run them.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:waveform_recorder/waveform_recorder.dart';
import 'package:waveform_recorder_example/main.dart';

// MIC selects which permission state the test expects; see README.md.
// ignore: do_not_use_environment
const mic = String.fromEnvironment('MIC');

final _log = <String>[];
void _note(String s) {
  _log.add(s);
  debugPrint(s);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() {
    IntegrationTestWidgetsFlutterBinding.instance.reportData = {
      'mic': mic,
      'log': _log,
    };
  });

  setUpAll(() {
    if (mic != 'denied' && mic != 'granted') {
      fail('pass --dart-define=MIC=denied|granted (got "$mic")');
    }
  });

  testWidgets('controller: start with mic $mic', (tester) async {
    final controller = WaveformRecorderController();
    var notifications = 0;
    controller.addListener(() => notifications++);

    if (mic == 'denied') {
      // twice: the second attempt proves the controller was left reusable,
      // not stuck reporting 'Already recording'
      for (var attempt = 1; attempt <= 2; attempt++) {
        Object? error;
        try {
          await controller.startRecording();
        } on Object catch (e) {
          error = e;
        }
        _note('MICTEST attempt $attempt error: $error');
        expect(error, isA<Exception>());
        expect(error.toString(), contains('Microphone permission denied'));
        expect(controller.isRecording, isFalse);
        expect(controller.isStarting, isFalse);
        expect(controller.startTime, isNull);
      }
      expect(notifications, 4);
    } else {
      await controller.startRecording();
      expect(controller.isRecording, isTrue);
      expect(controller.isStarting, isFalse);
      expect(controller.startTime, isNotNull);

      final amps = <Object>[];
      final sub = controller.amplitudeStream.listen(amps.add);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
      await sub.cancel();
      _note('MICTEST amplitudes received: ${amps.length}');
      expect(amps, isNotEmpty);

      await controller.stopRecording();
      final file = controller.file;
      _note(
        'MICTEST file: ${file?.uri} name: ${controller.fileName} '
        'mimeType: ${controller.mimeType} length: ${controller.length}',
      );
      expect(file, isNotNull);
      expect(controller.fileName, isNotNull);
      expect(controller.mimeType, startsWith('audio/'));
      expect(controller.length, greaterThan(Duration.zero));
      final bytes = await tester.runAsync(() => file!.length());
      _note('MICTEST file bytes: $bytes');
      expect(bytes, greaterThan(0));
    }

    controller.dispose();
  });

  testWidgets('example app: tap record with mic $mic', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // pump real frames until [done] holds, for at most [seconds]
    Future<void> pumpUntil(bool Function() done, {int seconds = 10}) async {
      final sw = Stopwatch()..start();
      while (!done() && sw.elapsed < Duration(seconds: seconds)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      _note('MICTEST waited ${sw.elapsedMilliseconds}ms');
    }

    void dump() {
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data);
      final tips = tester
          .widgetList<IconButton>(find.byType(IconButton))
          .map((b) => b.tooltip);
      _note('MICTEST texts: ${texts.toList()} tooltips: ${tips.toList()}');
    }

    final record = find.byTooltip('Start Recording');
    expect(record, findsOneWidget);
    await tester.tap(record);

    if (mic == 'denied') {
      final snack = find.text(
        'Could not start recording: Exception: Microphone permission denied',
      );
      await pumpUntil(() => snack.evaluate().isNotEmpty);
      dump();
      expect(snack, findsOneWidget);
      expect(find.byTooltip('Start Recording'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } else {
      final stop = find.byTooltip('Stop Recording');
      await pumpUntil(() => stop.evaluate().isNotEmpty);
      dump();
      expect(stop, findsOneWidget);
      expect(find.byType(WaveformRecorder), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await tester.tap(stop);
      final play = find.byTooltip('Play Recording');
      await pumpUntil(() => play.evaluate().isNotEmpty);
      dump();
      expect(find.byTooltip('Start Recording'), findsOneWidget);
      expect(play, findsOneWidget);
      final text = tester.widget<TextField>(find.byType(TextField));
      _note('MICTEST text field: ${text.controller?.text}');
      expect(text.controller?.text, contains('seconds'));
      expect(tester.takeException(), isNull);
    }
  });
}
