// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'package:datadog_common_test/datadog_common_test.dart';
import 'package:datadog_session_replay/datadog_session_replay.dart';
import 'package:datadog_session_replay/src/datadog_session_replay_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<MethodCall> log = [];

  // ignore: unused_local_variable
  MethodChannelDatadogSessionReplay platform =
      MethodChannelDatadogSessionReplay();
  const MethodChannel channel = MethodChannel(
    'datadog_sdk_flutter.session_replay',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          if (methodCall.method == 'enable') {
            return Future.value(true);
          }
          return null;
        });
  });

  tearDown(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('enable calls to channel with configuration', () async {
    // Given
    final mockEndpoint = randomString();
    final configuration = DatadogSessionReplayConfiguration(
      replaySampleRate: 1.0,
      customEndpoint: mockEndpoint,
    );

    // When
    final success = await platform.enable(configuration, (_) {});

    // Then
    expect(success, isTrue);
    expect(log, [
      isMethodCall(
        'enable',
        arguments: {
          'configuration': {'customEndpoint': mockEndpoint},
        },
      ),
    ]);
  });

  test('setHasReplay calls to channel', () async {
    // Given
    final mockHasReplay = randomBool();

    // When
    await platform.setHasReplay(mockHasReplay);

    // Then
    expect(log, [
      isMethodCall('setHasReplay', arguments: {'hasReplay': mockHasReplay}),
    ]);
  });

  test('writeSegment calls to channel', () async {
    // Given
    final mockSegment = randomString();
    final mockViewId = randomString();

    // When
    await platform.writeSegment(mockSegment, mockViewId);

    // Then
    expect(log, [
      isMethodCall(
        'writeSegment',
        arguments: {'segment': mockSegment, 'viewId': mockViewId},
      ),
    ]);
  });

  test('setRecordCount calls to channel', () async {
    // Given
    final mockViewId = randomString();
    final mockRecordCount = randomInt();

    // when
    await platform.setRecordCount(mockViewId, mockRecordCount);

    // Then
    expect(log, [
      isMethodCall(
        'setRecordCount',
        arguments: {'viewId': mockViewId, 'count': mockRecordCount},
      ),
    ]);
  });
}
