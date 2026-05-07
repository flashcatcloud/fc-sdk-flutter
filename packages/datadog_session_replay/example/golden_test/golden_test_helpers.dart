// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/processor/processor_worker.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/capture/simple_test_capture.dart';
import 'snapshot_renderer.dart';

typedef TestActions = Future<void> Function();

Future<void> snapshotTest(
  WidgetTester tester,
  SessionReplayRecorder recorder,
  Widget fixture, {
  TestActions? testActions,
  FontFamilyTransformConfig fontFamilyTransform =
      const FontFamilyTransformConfig(),
}) async {
  final processor = ProcessorWorker(fontFamilyTransform: fontFamilyTransform);
  await tester.pumpWidget(
    SimpleTestCapture(key: Key('key'), recorder: recorder, child: fixture),
  );
  await tester.pumpAndSettle();
  await testActions?.call();

  List<SRWireframe> wireframes = [];
  await tester.runAsync(() async {
    final capture = await recorder.performCapture();
    // This is a test so safe to ignore invalid use lint
    // ignore: invalid_use_of_visible_for_testing_member
    wireframes = processor.generateWireframes(capture!);
  });

  await tester.pumpWidget(
    CustomPaint(painter: WireframeCustomPainter(wireframes)),
  );
  await tester.pumpAndSettle();
  final goldenName = tester.testDescription.toLowerSnakeCase();
  await expectLater(
    find.byType(CustomPaint),
    matchesGoldenFile('goldens/$goldenName.png'),
  );
}

extension on String {
  String toLowerSnakeCase() {
    return toLowerCase().replaceAll(' ', '_');
  }
}
