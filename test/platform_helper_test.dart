import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waveform_recorder/src/platform_helper/platform_helper.dart';

void main() {
  test('waitForTempAudioFile waits for a non-empty stable file', () async {
    final dir = await Directory.systemTemp.createTemp(
      'waveform_recorder_test_',
    );
    addTearDown(() => dir.delete(recursive: true));

    final file = File('${dir.path}/recording.m4a');
    var completed = false;
    final wait = PlatformHelper.waitForTempAudioFile(
      file.path,
      pollInterval: const Duration(milliseconds: 10),
      timeout: const Duration(seconds: 1),
    ).then((_) => completed = true);

    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(completed, isFalse);

    await file.writeAsBytes([1, 2, 3]);
    await wait;

    expect(completed, isTrue);
  });

  test('waitForTempAudioFile times out when the file never appears', () async {
    final dir = await Directory.systemTemp.createTemp(
      'waveform_recorder_test_',
    );
    addTearDown(() => dir.delete(recursive: true));

    await expectLater(
      PlatformHelper.waitForTempAudioFile(
        '${dir.path}/missing.m4a',
        pollInterval: const Duration(milliseconds: 5),
        timeout: const Duration(milliseconds: 20),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}
