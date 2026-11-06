import 'dart:convert';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async =>
      // the driver runs on the host; stdout is how the report gets out
      // ignore: avoid_print
      print('MICREPORT ${jsonEncode(data)}'),
);
