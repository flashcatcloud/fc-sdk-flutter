// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ui' as ui;

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/image_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';
import 'simple_test_capture.dart';

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;

  setUp(() {
    final KeyGenerator keyGenerator = KeyGenerator();
    recorder = SessionReplayRecorder.withCustomRecorders(
      [ImageRecorder(keyGenerator)],
      defaultCapturePrivacy: CapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
      ),
    );

    registerFallbackValue(
      CapturedViewAttributes(paintBounds: Rect.zero, scaleX: 1.0, scaleY: 1.0),
    );

    context = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
    );
    recorder.updateContext(context);
  });

  testWidgets('returns node for Image', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);
    final width = randomDouble(min: 10, max: 50);
    final height = randomDouble(min: 10, max: 50);

    ui.Image? testImage = await tester.runAsync(() {
      return createTestImage(width: width.toInt(), height: height.toInt());
    });

    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: y,
              left: x,
              width: width,
              height: height,
              child: Image(image: TestImageProvider(testImage!)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = recorder.performCapture();

    // Then
    expect(capture!.viewTreeSnapshot.nodes.length, 1);

    final capturedImageNode = capture.viewTreeSnapshot.nodes.last;
    expect(capturedImageNode.attributes.x, x.round());
    expect(capturedImageNode.attributes.y, y.round());
    expect(capturedImageNode.attributes.width, width.round());
    expect(capturedImageNode.attributes.height, height.round());
  });

  testWidgets('captured image builds placeholder wireframe', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);
    final width = randomDouble(min: 10, max: 50);
    final height = randomDouble(min: 10, max: 50);

    ui.Image? testImage = await tester.runAsync(() {
      return createTestImage(width: width.round(), height: height.round());
    });

    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: y,
              left: x,
              width: width,
              height: height,
              child: Image(image: TestImageProvider(testImage!)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = recorder.performCapture();

    // Then
    expect(capture!.viewTreeSnapshot.nodes.length, 1);

    final capturedImageNode = capture.viewTreeSnapshot.nodes.last;
    final builtWireframes = capturedImageNode.buildWireframes();
    expect(builtWireframes.length, 1);
    final wireframe = builtWireframes.first as SRPlaceholderWireframe;

    expect(wireframe.x, x.round());
    expect(wireframe.y, y.round());
    expect(wireframe.width, width.round());
    expect(wireframe.height, height.round());
  });

  testWidgets('captured image below width has no label', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);
    final width = randomDouble(min: 10, max: 50);
    final height = randomDouble(min: 10, max: 50);

    ui.Image? testImage = await tester.runAsync(() {
      return createTestImage(width: width.round(), height: height.round());
    });

    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: y,
              left: x,
              width: width,
              height: height,
              child: Image(image: TestImageProvider(testImage!)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = recorder.performCapture();

    // Then
    expect(capture!.viewTreeSnapshot.nodes.length, 1);

    final capturedImageNode = capture.viewTreeSnapshot.nodes.last;
    final builtWireframes = capturedImageNode.buildWireframes();
    expect(builtWireframes.length, 1);
    final wireframe = builtWireframes.first as SRPlaceholderWireframe;

    expect(wireframe.label, isNull);
  });

  testWidgets('captured image above width has label', (tester) async {
    // Given
    final x = randomDouble(min: 10, max: 50);
    final y = randomDouble(min: 10, max: 50);
    final width = randomDouble(min: 200, max: 400);
    final height = randomDouble(min: 10, max: 50);

    ui.Image? testImage = await tester.runAsync(() {
      return createTestImage(width: width.round(), height: height.round());
    });

    final tree = MaterialApp(
      home: SimpleTestCapture(
        key: Key('key'),
        recorder: recorder,
        child: Stack(
          children: [
            Positioned(
              top: y,
              left: x,
              width: width,
              height: height,
              child: Image(image: TestImageProvider(testImage!)),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = recorder.performCapture();

    // Then
    expect(capture!.viewTreeSnapshot.nodes.length, 1);

    final capturedImageNode = capture.viewTreeSnapshot.nodes.last;
    final builtWireframes = capturedImageNode.buildWireframes();
    expect(builtWireframes.length, 1);
    final wireframe = builtWireframes.first as SRPlaceholderWireframe;

    expect(wireframe.label, 'Content Image');
  });
}
