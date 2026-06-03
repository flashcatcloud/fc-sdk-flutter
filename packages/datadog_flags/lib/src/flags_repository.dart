// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'assignment.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_context.dart';
import 'flags_store.dart';
import 'json_value.dart';

class FlagsRepository {
  final String clientName;
  final FlagAssignmentsFetcher fetcher;
  final DatadogFlagsStore store;
  final DateTime Function() dateProvider;

  FlagsData? _state;
  int _contextRequestId = 0;

  FlagsRepository({
    required this.clientName,
    required this.fetcher,
    required this.store,
    required this.dateProvider,
  });

  DatadogFlagsEvaluationContext? get context => _state?.context;

  FlagAssignment? flagAssignment(String key) => _state?.flags[key];

  Future<void> setEvaluationContext(
    DatadogFlagsEvaluationContext context,
  ) async {
    final requestId = ++_contextRequestId;
    final cached = await store.read(clientName);
    if (requestId != _contextRequestId) {
      return;
    }
    if (cached != null && _contextsMatch(cached.context, context)) {
      _state = cached;
    }

    final flags = await fetcher.fetch(context);
    if (requestId != _contextRequestId) {
      return;
    }

    _state = FlagsData(
      flags: flags,
      context: context,
      date: dateProvider(),
    );
    await store.write(clientName, _state!);
  }

  Future<void> reset() async {
    _state = null;
    await store.delete(clientName);
  }
}

bool _contextsMatch(
  DatadogFlagsEvaluationContext left,
  DatadogFlagsEvaluationContext right,
) {
  return left.targetingKey == right.targetingKey &&
      sortedJson(left.attributes).toString() ==
          sortedJson(right.attributes).toString();
}
