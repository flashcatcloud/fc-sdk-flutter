// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flashcat_flutter_plugin/src/rum/ddrum_app_launch.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('asks for an app launch on every Android platform target', () {
    // Deliberately not conditioned on who initialized the native SDK: the host
    // cannot tell whether the native detector observed the first Activity, so it
    // always asks and the native SDK declines when its detector already reported.
    expect(
      shouldRegisterAppLaunchCallback(isWeb: false, isAndroid: true),
      isTrue,
    );
    expect(
      shouldRegisterAppLaunchCallback(isWeb: false, isAndroid: false),
      isFalse,
    );
    expect(
      shouldRegisterAppLaunchCallback(isWeb: true, isAndroid: true),
      isFalse,
    );
  });

  group('frameAgeNsFromTimestamps', () {
    test('converts a plausible positive age to nanoseconds', () {
      expect(
        frameAgeNsFromTimestamps(
          nowUs: 2 * Duration.microsecondsPerSecond,
          rasterFinishUs: Duration.microsecondsPerSecond,
        ),
        Duration.microsecondsPerSecond * 1000,
      );
    });

    test('falls back to zero for non-positive ages', () {
      expect(
        frameAgeNsFromTimestamps(nowUs: 100, rasterFinishUs: 100),
        0,
      );
      expect(
        frameAgeNsFromTimestamps(nowUs: 100, rasterFinishUs: 101),
        0,
      );
    });

    test('falls back to zero for ages of ten seconds or more', () {
      expect(
        frameAgeNsFromTimestamps(
          nowUs: 10 * Duration.microsecondsPerSecond,
          rasterFinishUs: 0,
        ),
        0,
      );
      expect(
        frameAgeNsFromTimestamps(
          nowUs: 11 * Duration.microsecondsPerSecond,
          rasterFinishUs: 0,
        ),
        0,
      );
    });
  });
}
