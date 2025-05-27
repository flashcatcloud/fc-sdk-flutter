// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/container_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/extensions.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'simple_test_capture.dart';

// Note: to properly test recorders, we need to supply a full widget tree, as Element
// is too difficult to mock effectively.
void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;

  setUp(() {
    recorder = SessionReplayRecorder.withCustomRecorders([
      ContainerRecorder(KeyGenerator()),
    ]);

    registerFallbackValue(
      CapturedViewAttributes(paintBounds: Rect.zero, scaleX: 1.0, scaleY: 1.0),
    );

    context = RUMContext(
      applicationId: randomString(),
      sessionId: randomString(),
    );
    recorder.updateContext(context);
  });

  testWidgets('container returns captured node semantics', (tester) async {
    // Given
    final width = randomDouble(min: 10, max: 50);
    final height = randomDouble(min: 10, max: 50);
    final color = randomColor();
    final tree = SimpleTestCapture(
      key: Key('key'),
      recorder: recorder,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Container(
              color: color,
              width: width,
              height: height,
              child: Placeholder(),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = recorder.performCapture();

    // Then
    expect(capture, isNotNull);
    final treeCapture = capture!.viewTreeSnapshot;
    expect(treeCapture, isNotNull);
    expect(treeCapture.nodes.length, 1);
    final containerNode = treeCapture.nodes.first;
    expect(containerNode.attributes.x, 0);
    expect(containerNode.attributes.y, 0);
    expect(containerNode.attributes.width, width.round());
    expect(containerNode.attributes.height, height.round());

    final builtWireframes = containerNode.buildWireframes();
    expect(builtWireframes.length, 1);
    final shapeWireframe = builtWireframes.first as SRShapeWireframe;
    expect(shapeWireframe.x, 0);
    expect(shapeWireframe.y, 0);
    expect(shapeWireframe.width, width.round());
    expect(shapeWireframe.height, height.round());
    expect(shapeWireframe.shapeStyle!.backgroundColor, color.toHexString());
  });

  testWidgets('container returns box decoration in wireframe', (tester) async {
    // Given
    final width = randomDouble(min: 10, max: 50);
    final height = randomDouble(min: 10, max: 50);
    final color = randomColor();
    final tree = SimpleTestCapture(
      key: Key('key'),
      recorder: recorder,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color,
                border: Border.all(width: 3.4, color: color),
                borderRadius: BorderRadius.circular(10.0),
              ),
              width: width,
              height: height,
              child: Placeholder(),
            ),
          ],
        ),
      ),
    );
    await tester.pumpWidget(tree);

    // When
    final capture = recorder.performCapture();

    // Then
    expect(capture, isNotNull);
    final treeCapture = capture!.viewTreeSnapshot;
    final containerNode = treeCapture.nodes.first;

    final builtWireframes = containerNode.buildWireframes();
    final shapeWireframe = builtWireframes.first as SRShapeWireframe;
    expect(shapeWireframe.border, isNotNull);
    expect(shapeWireframe.border!.color, color.toHexString());
    expect(shapeWireframe.border!.width, 3);
    expect(shapeWireframe.shapeStyle!.cornerRadius, 10.0);
    expect(shapeWireframe.shapeStyle!.backgroundColor, color.toHexString());
  });
}
