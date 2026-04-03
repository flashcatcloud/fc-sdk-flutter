// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

// Note: to properly test recorders, we need to supply a full widget tree, as Element
// is too difficult to mock effectively.
import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/element_recorders/material_widgets/checkbox_recorder.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:datadog_session_replay/src/sr_data_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../simple_test_capture.dart';


SimpleTestCapture captureCheckbox(
  SessionReplayRecorder recorder,
  Widget checkbox,
) {

  return SimpleTestCapture(
    key: Key('key'),
    recorder: recorder,
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: checkbox,
        ),
      ),
    ),
  );
}

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;

  setUp(() {
    recorder = SessionReplayRecorder.withCustomRecorders(
      [CheckboxRecorder(KeyGenerator())],
      defaultCapturePrivacy: TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      ),
      touchPrivacyLevel: TouchPrivacyLevel.show,
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

  group('symbol output', () {

    testWidgets('checked checkbox has checkmark symbol', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {})
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      expect(treeCapture.nodes.length, 1);        // It should be just one node, the checkbox node
      final checkboxNode = treeCapture.nodes.first;

      final wireframes = checkboxNode.buildWireframes();
      expect(wireframes.length, 1);
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.text, '\u2713');
    });

    testWidgets('unchecked checkbox has empty text', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: false, onChanged: (_) {})
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;

      final wireframes = checkboxNode.buildWireframes();
      expect(wireframes.length, 1);
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.text, '');
    });

    testWidgets('tristate checkbox has dash symbol', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: null, tristate: true, onChanged: (_) {})
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      expect(treeCapture.nodes.length, 1);        // It should be just one node, the checkbox node
      final checkboxNode = treeCapture.nodes.first;

      final wireframes = checkboxNode.buildWireframes();
      expect(wireframes.length, 1);
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.text, '\u2014');
    });
  });

  group('fill color', () {

    testWidgets('checked checkbox has non-transparent fill', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {})
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.shapeStyle!.backgroundColor, isNot('#00000000'));

    });

    testWidgets('checked checkbox has a specific fill color', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {}, activeColor: Colors.blue)
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      // Colors.blue (#ff2196f3)
      expect(checkboxWireframe.shapeStyle!.backgroundColor, '#2196f3ff');

    });

    testWidgets('unchecked checkbox has transparent fill', (tester) async {

      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: false, onChanged: (_) {})
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.shapeStyle!.backgroundColor, '#00000000');

    });

    testWidgets('tristate checkbox has non-transparent fill', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: null, tristate: true, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.shapeStyle!.backgroundColor, isNot('#00000000'));
    });

    testWidgets('disabled checked checkbox has fill with reduced alpha', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: null, activeColor: Colors.blue),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      // Colors.blue (#ff2196f3) with alpha 0.38 --> round(0.38 * 255) = 97 = 0x61
      expect(checkboxWireframe.shapeStyle!.backgroundColor, '#2196f361');
    });
  });

  group('border', () {

    testWidgets('unchecked checkbox has a border', (tester) async {

      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: false, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.border, isNotNull);
      expect(checkboxWireframe.border!.width, 2);
    });

    testWidgets('checked checkbox has no border', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.border, isNull);
    });

    testWidgets('tristate checkbox has no border', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: null, tristate: true, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.border, isNull);
    });

    testWidgets('unchecked checkbox uses custom side color and width', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(
          value: false,
          onChanged: (_) {},
          side: BorderSide(color: Colors.red, width: 3),
        ),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      // Colors.red (#fff44336) with full alpha --> #f44336ff
      expect(checkboxWireframe.border!.color, '#f44336ff');
      expect(checkboxWireframe.border!.width, 3);
    });
  });

  group('layout and size', () {

    testWidgets('checkbox produces a single wireframe node', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      expect(capture!.viewTreeSnapshot.nodes.length, 1);
    });

    testWidgets('checkbox has default size of 18x18', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.width, 18);
      expect(checkboxWireframe.height, 18);
    });

    testWidgets('checkbox respects visual density', (tester) async {
      // Given
      // VisualDensity.baseSizeAdjustment = Offset(horizontal * 4, vertical * 4)
      // horizontal: 2, vertical: 2 --> adjustment = Offset(8, 8) --> size = 18 + 8 = 26
      final tree = captureCheckbox(
        recorder,
        Checkbox(
          value: true,
          onChanged: (_) {},
          visualDensity: VisualDensity(horizontal: 2, vertical: 2),
        ),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.width, 26);
      expect(checkboxWireframe.height, 26);
    });

    testWidgets('scaled checkbox has scaled size', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Transform.scale(
          scale: 0.5,
          child: Checkbox(value: true, onChanged: (_) {}),
        ),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      // 18 * 0.5 = 9
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.width, 9);
      expect(checkboxWireframe.height, 9);
    });
  });

  group('text style', () {

    testWidgets('symbol color comes from checkColor', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {}, checkColor: Colors.red),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      // Colors.red (#f44336) with full alpha --> #f44336ff
      expect(checkboxWireframe.textStyle.color, '#f44336ff');
    });

    testWidgets('symbol size is 70% of the checkbox height', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      // Default height = 18, textScale = 0.7 → (18 * 0.7).round() = 13
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.textStyle.size, (checkboxWireframe.height * 0.7).round());
    });

    testWidgets('symbol is center aligned horizontally and vertically', (tester) async {
      // Given
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.textPosition?.alignment?.horizontal, SRHorizontalAlignment.center);
      expect(checkboxWireframe.textPosition?.alignment?.vertical, SRVerticalAlignment.center);
    });
  });

  group('privacy', () {

    testWidgets('maskAllInputs masks checked checkbox with x symbol', (tester) async {
      // Given
      recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      );
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.text, 'x');
      expect(checkboxWireframe.shapeStyle!.backgroundColor, '#00000000');
      expect(checkboxWireframe.border, isNotNull);
    });

    testWidgets('maskAll masks checked checkbox with x symbol', (tester) async {
      // Given
      recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAll,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      );
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.text, 'x');
      expect(checkboxWireframe.shapeStyle!.backgroundColor, '#00000000');
      expect(checkboxWireframe.border, isNotNull);
    });

    testWidgets('maskAllInputs masks unchecked checkbox with x symbol', (tester) async {
      // Given — verifies state is hidden regardless of original value
      recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskAllInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      );
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: false, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.text, 'x');
    });

    testWidgets('maskSensitiveInputs does not mask checkbox', (tester) async {
      // Given — maskSensitiveInputs only masks obscureText fields, not checkboxes
      recorder.defaultTreeCapturePrivacy = TreeCapturePrivacy(
        textAndInputPrivacyLevel: TextAndInputPrivacyLevel.maskSensitiveInputs,
        imagePrivacyLevel: ImagePrivacyLevel.maskNonAssetsOnly,
      );
      final tree = captureCheckbox(
        recorder,
        Checkbox(value: true, onChanged: (_) {}),
      );
      await tester.pumpWidget(tree);

      // When
      final capture = await recorder.performCapture();

      // Then
      expect(capture, isNotNull);
      final treeCapture = capture!.viewTreeSnapshot;
      final checkboxNode = treeCapture.nodes.first;
      final wireframes = checkboxNode.buildWireframes();
      final checkboxWireframe = wireframes.first as SRTextWireframe;
      expect(checkboxWireframe.text, '\u2713');
    });
  });
}
