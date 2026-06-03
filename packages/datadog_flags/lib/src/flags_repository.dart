// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'assignment.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_context.dart';

class FlagsRepository {
  final FlagAssignmentsFetcher fetcher;

  DatadogFlagsEvaluationContext? _context;
  Map<String, FlagAssignment> _flags = const {};
  int _contextRequestId = 0;

  FlagsRepository({
    required this.fetcher,
  });

  DatadogFlagsEvaluationContext? get context => _context;

  FlagAssignment? flagAssignment(String key) => _flags[key];

  Future<void> setEvaluationContext(
    DatadogFlagsEvaluationContext context,
  ) async {
    final requestId = ++_contextRequestId;
    final flags = await fetcher.fetch(context);
    if (requestId != _contextRequestId) {
      return;
    }

    _context = context;
    _flags = flags;
  }

  Future<void> reset() async {
    _context = null;
    _flags = const {};
  }
}
