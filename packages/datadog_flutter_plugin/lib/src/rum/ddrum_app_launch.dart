// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2022 Datadog, Inc.

const _maxPlausibleFrameAgeUs = 10 * Duration.microsecondsPerSecond;

/// Whether this platform should ask the native SDK to report an app launch.
///
/// Deliberately not conditioned on who initialized the native SDK. Initializing
/// it before Flutter attaches does not mean it initialized early enough for the
/// native detector to observe the first Activity, so "not Flutter-owned" is not
/// a safe proxy for "the native detector has it covered" - assuming it was lost
/// the launch entirely on such hosts. The native SDK arbitrates instead: it
/// reports only when its own detector did not.
bool shouldRegisterAppLaunchCallback({
  required bool isWeb,
  required bool isAndroid,
}) {
  return !isWeb && isAndroid;
}

int frameAgeNsFromTimestamps({
  required int nowUs,
  required int rasterFinishUs,
}) {
  final ageUs = nowUs - rasterFinishUs;
  if (ageUs <= 0 || ageUs >= _maxPlausibleFrameAgeUs) return 0;
  return ageUs * 1000;
}
