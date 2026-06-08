// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'assignment.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_context.dart';

class FlagsRepository {
  final FlagAssignmentsFetcher fetcher;

  FlagsEvaluationContext? _context;
  Map<String, FlagAssignment> _flags = const {};
  int _contextRequestId = 0;

  FlagsRepository({
    required this.fetcher,
  });

  FlagsEvaluationContext? get context => _context;

  FlagAssignment? flagAssignment(String key) => _flags[key];

  Future<void> setEvaluationContext(
    FlagsEvaluationContext context,
  ) async {
    // Multiple context updates can be in flight at once. Only the latest
    // request is allowed to publish assignments back into the repository.
    final requestId = ++_contextRequestId;
    final PrecomputedAssignments assignments;
    try {
      assignments = await fetcher.fetch(context);
    } catch (_) {
      if (requestId == _contextRequestId) {
        _context = null;
        _flags = const {};
      }
      return;
    }

    if (requestId != _contextRequestId) {
      return;
    }

    _context = context;
    _flags = assignments.flags;
  }

  Future<void> reset() async {
    _contextRequestId++;
    _context = null;
    _flags = const {};
  }
}
