# Microphone permission tests

`permission_test.dart` runs on a real device, simulator, emulator or browser.
It checks that `startRecording()` behaves correctly when microphone access
is denied and when it is granted. The test doesn't change the permission
itself. Put the platform into the state you want, then pass the matching
`--dart-define=MIC=denied` or `--dart-define=MIC=granted`.

With the permission **denied**, the test expects `startRecording()` to throw
`Exception: Microphone permission denied` twice in a row, which proves the
controller is left reusable. It also expects the example app to show that
error in a `SnackBar` and return the record button to idle.

With the permission **granted**, the test expects a recording to start,
amplitudes to arrive, and stopping to produce a non-empty file. The example
app must reach the stopped state with a playable recording.

Run the commands below from the `example` directory.

## Android

Install the app once, for example with `flutter run`. Then set the
permission. The `user-fixed` flag denies without showing a dialog.

```sh
P=com.example.example
# denied
adb shell pm revoke $P android.permission.RECORD_AUDIO
adb shell pm set-permission-flags $P android.permission.RECORD_AUDIO user-fixed
# granted
adb shell pm clear-permission-flags $P android.permission.RECORD_AUDIO user-fixed
adb shell pm grant $P android.permission.RECORD_AUDIO

flutter test integration_test/permission_test.dart -d <device> --dart-define=MIC=denied
```

## iOS Simulator

```sh
xcrun simctl privacy <udid> revoke microphone com.example.wave-runner   # denied
xcrun simctl privacy <udid> grant microphone com.example.wave-runner    # granted
flutter test integration_test/permission_test.dart -d <udid> --dart-define=MIC=denied
```

## macOS

macOS asks the first time the app wants the microphone. Answer the prompt, or
set the answer afterward in System Settings > Privacy & Security > Microphone.
Run `tccutil reset Microphone com.example.waveformRecorderExample` to see the
prompt again. Then run:

```sh
flutter test integration_test/permission_test.dart -d macos --dart-define=MIC=denied
```

TCC attributes a process launched from an SSH session to `sshd`, not to the
app. In that case macOS denies the microphone without prompting, whatever the
app's own setting says.

## Web

Web tests run through `flutter drive` with
[chromedriver](https://googlechromelabs.github.io/chrome-for-testing/)
listening on port 4444. Chrome flags select the permission state:
`--use-fake-device-for-media-stream` supplies a test tone, so you don't need a
real microphone.

```sh
chromedriver --port=4444 &
# denied
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/permission_test.dart -d web-server \
  --browser-name=chrome --dart-define=MIC=denied \
  --web-browser-flag=--deny-permission-prompts
# granted
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/permission_test.dart -d web-server \
  --browser-name=chrome --dart-define=MIC=granted \
  --web-browser-flag=--use-fake-ui-for-media-stream \
  --web-browser-flag=--use-fake-device-for-media-stream
```

The driver prints the test's observations as a `MICREPORT` JSON line.
