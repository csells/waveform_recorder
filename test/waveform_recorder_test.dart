import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waveform_recorder/waveform_recorder.dart';

void main() {
  testWidgets('WaveformRecorder does not throw after recording stops', (
    tester,
  ) async {
    final controller = WaveformRecorderController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: WaveformRecorder(
          height: 48,
          controller: controller,
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
