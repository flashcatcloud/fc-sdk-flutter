// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/capture/capture_node.dart';
import 'package:datadog_session_replay/src/capture/recorder.dart';
import 'package:datadog_session_replay/src/processor/processor_worker.dart';
import 'package:datadog_session_replay/src/rum_context.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../test/capture/simple_test_capture.dart';
import 'snapshot_renderer.dart';

typedef TestActions = Future<void> Function();

void main() {
  late SessionReplayRecorder recorder;
  late RUMContext context;

  setUp(() {
    recorder = SessionReplayRecorder(
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

  Future<void> snapshotTest(
    WidgetTester tester,
    Widget fixture, {
    TestActions? testActions,
  }) async {
    final processor = ProcessorWorker();
    await tester.pumpWidget(
      SimpleTestCapture(key: Key('key'), recorder: recorder, child: fixture),
    );
    await tester.pumpAndSettle();
    await testActions?.call();

    final capture = recorder.performCapture();
    // This is a test so safe to ignore invalid use lint
    // ignore: invalid_use_of_visible_for_testing_member
    final wireframes = processor.generateWireframes(capture!);

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

  testWidgets('simple containers', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Simple Containers')),
        body: Center(
          child: Column(
            children: [
              Material(
                elevation: 8.0,
                color: Colors.amberAccent,
                surfaceTintColor: Colors.purple,
                child: SizedBox(
                  width: 100,
                  height: 200,
                  child: Center(child: Text('In a Material')),
                ),
              ),
              const SizedBox(width: 0, height: 20),
              ElevatedButton(onPressed: () {}, child: Text('My Button')),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(width: 2),
                  borderRadius: BorderRadius.circular(10.0),
                  color: Colors.blueAccent,
                ),
                width: 200.0,
                height: 200.0,
                alignment: Alignment.center,
                child: Text('In a Container\n'),
              ),
            ],
          ),
        ),
      ),
    );
    await snapshotTest(tester, fixture);
  });

  testWidgets('unfocused text fields', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Unfocused Text Fields')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              spacing: 12,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Simple Text Field'),
                ),
                CupertinoTextField(placeholder: 'Cupertino Text Field'),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Bordered Text Field',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Multiline Text Field',
                    border: OutlineInputBorder(),
                  ),
                  minLines: 3,
                  maxLines: 5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(tester, fixture);
  });

  testWidgets('focused material text field', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Focused Material Field')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              spacing: 12,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Simple Text Field'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(
      tester,
      fixture,
      testActions: () async {
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('material text field with content', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Focused Material Field')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              spacing: 12,
              children: [
                TextField(
                  decoration: InputDecoration(labelText: 'Simple Text Field'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(
      tester,
      fixture,
      testActions: () async {
        final textField = find.byType(TextField);
        await tester.tap(textField);
        await tester.pumpAndSettle();
        await tester.enterText(textField, 'testing');
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('focused cupertino text field', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Focused cupertino Field')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              spacing: 12,
              children: [
                CupertinoTextField(placeholder: 'Cupertino Text Field'),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(
      tester,
      fixture,
      testActions: () async {
        await tester.tap(find.byType(CupertinoTextField));
        await tester.pumpAndSettle();
      },
    );
  });

  testWidgets('cupertino text field with content', (tester) async {
    final fixture = MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Focused Material Field')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              spacing: 12,
              children: [
                CupertinoTextField(placeholder: 'Cupertino Text Field'),
              ],
            ),
          ),
        ),
      ),
    );
    await snapshotTest(
      tester,
      fixture,
      testActions: () async {
        final textField = find.byType(CupertinoTextField);
        await tester.tap(textField);
        await tester.pumpAndSettle();
        await tester.enterText(textField, 'testing');
        await tester.pumpAndSettle();
      },
    );
  });
}

extension SnakeCase on String {
  String toLowerSnakeCase() {
    return toLowerCase().replaceAll(' ', '_');
  }
}
