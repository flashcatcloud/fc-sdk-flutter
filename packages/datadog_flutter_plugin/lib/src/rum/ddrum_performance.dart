// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

import 'rum_configuration.dart';

bool shouldSampleRefreshRate({
  required bool isWeb,
  required bool isAndroid,
  required VitalsFrequency? vitalUpdateFrequency,
}) {
  return !isWeb && isAndroid && vitalUpdateFrequency != null;
}

double? frameIntervalForRefreshRate(
  double buildDurationSeconds,
  double displayRefreshRate,
) {
  if (buildDurationSeconds <= 0) return null;

  final rawRate = 1.0 / buildDurationSeconds;
  final cappedRate =
      rawRate < displayRefreshRate ? rawRate : displayRefreshRate;
  final normalizedRate = cappedRate * 60.0 / displayRefreshRate;
  if (normalizedRate <= 1.0) return null;

  return 1.0 / normalizedRate;
}
