// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:convert';

import 'assignment.dart';
import 'evaluation_context.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_store.dart';

class FlagsRepository {
  final String clientName;
  final FlagAssignmentsFetcher fetcher;
  final DatadogFlagsStore? store;
  final DateTime Function() dateProvider;

  FlagsData? _state;
  int _contextRequestId = 0;
  Future<void> _cacheOperation = Future<void>.value();

  FlagsRepository({
    required this.clientName,
    required this.fetcher,
    this.store,
    required this.dateProvider,
  });

  FlagsEvaluationContext? get context => _state?.context;

  FlagAssignment? flagAssignment(String key) => _state?.flags[key];

  Future<void> initialize(FlagsEvaluationContext context) async {
    final requestId = ++_contextRequestId;
    final cached = await _readCached();
    if (requestId != _contextRequestId) {
      return;
    }
    var restoredCachedAssignments = false;
    if (cached != null && _contextsMatch(cached.context, context)) {
      _state = cached;
      restoredCachedAssignments = true;
    }

    final PrecomputedAssignments assignments;
    try {
      assignments = await fetcher.fetch(context);
    } catch (_) {
      if (!restoredCachedAssignments && requestId == _contextRequestId) {
        _state = null;
      }
      return;
    }

    if (requestId != _contextRequestId) {
      return;
    }

    _state = FlagsData(
      flags: assignments.flags,
      context: context,
      date: dateProvider(),
    );
    await _writeCached(_state!);
  }

  Future<void> clearMemory() async {
    _contextRequestId++;
    _state = null;
  }

  Future<void> reset() async {
    await clearMemory();
    await _deleteCached();
  }

  Future<FlagsData?> _readCached() async {
    try {
      final encoded = await store?.read(clientName);
      return encoded == null ? null : FlagsData.fromJson(encoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCached(FlagsData data) async {
    await _enqueueCacheOperation(() async {
      try {
        await store?.write(clientName, data.toJson());
      } catch (_) {
        return;
      }
    });
  }

  Future<void> _deleteCached() async {
    await _enqueueCacheOperation(() async {
      try {
        await store?.delete(clientName);
      } catch (_) {
        return;
      }
    });
  }

  Future<void> _enqueueCacheOperation(Future<void> Function() operation) {
    final next = _cacheOperation.then((_) => operation());
    _cacheOperation = next.catchError((_) {});
    return next;
  }
}

bool _contextsMatch(FlagsEvaluationContext left, FlagsEvaluationContext right) {
  return left.targetingKey == right.targetingKey &&
      jsonEncode(_sortedJson(left.attributes)) ==
          jsonEncode(_sortedJson(right.attributes));
}

Object? _sortedJson(Object? value) {
  if (value is Map<Object?, Object?>) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return {
      for (final entry in entries)
        entry.key.toString(): _sortedJson(entry.value),
    };
  }
  if (value is Iterable<Object?>) {
    return value.map(_sortedJson).toList();
  }
  return value;
}
