// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'package:flashcat_flutter_plugin/src/rum/ddrum_performance.dart';
import 'package:flashcat_flutter_plugin/src/rum/rum_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldSampleRefreshRate', () {
    test('samples on Android when vitals use the default frequency', () {
      expect(
        shouldSampleRefreshRate(
          isWeb: false,
          isAndroid: true,
          vitalUpdateFrequency: VitalsFrequency.average,
        ),
        isTrue,
      );
    });

    test('does not sample when vitals are disabled', () {
      expect(
        shouldSampleRefreshRate(
          isWeb: false,
          isAndroid: true,
          vitalUpdateFrequency: null,
        ),
        isFalse,
      );
    });

    test('does not sample outside Android', () {
      expect(
        shouldSampleRefreshRate(
          isWeb: false,
          isAndroid: false,
          vitalUpdateFrequency: VitalsFrequency.average,
        ),
        isFalse,
      );
      expect(
        shouldSampleRefreshRate(
          isWeb: true,
          isAndroid: true,
          vitalUpdateFrequency: VitalsFrequency.average,
        ),
        isFalse,
      );
    });
  });

  group('frameIntervalForRefreshRate', () {
    test('normalizes a valid frame duration to a 60 Hz baseline', () {
      expect(frameIntervalForRefreshRate(0.01, 120.0), closeTo(1 / 50, 1e-9));
    });

    test('drops normalized rates at or below 1 Hz', () {
      expect(frameIntervalForRefreshRate(1.0, 60.0), isNull);
      expect(frameIntervalForRefreshRate(2.0, 60.0), isNull);
    });

    test('drops zero-duration frames', () {
      expect(frameIntervalForRefreshRate(0.0, 120.0), isNull);
    });
  });
}
