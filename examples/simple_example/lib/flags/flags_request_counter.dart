// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'package:flutter/foundation.dart';

abstract interface class FlagsRequestCounter implements Listenable {
  int get precomputeRequestCount;
  int get exposureCount;
  int get evaluationRequestCount;
  int get evaluationEventCount;
  int? get lastPrecomputeFlagCount;
  int? get lastPrecomputePayloadBytes;
  int? get lastPrecomputeStatusCode;
  Duration? get lastPrecomputeHttpDuration;
  Duration? get lastPrecomputePayloadParseDuration;

  Future<void> stop();
}
