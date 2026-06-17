// Unless explicitly stated otherwise all files in this repository are licensed
// under the Apache License Version 2.0. This product includes software
// developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-Present Datadog, Inc.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';

import 'assignment.dart';
import 'evaluation_context.dart';
import 'flag_assignments_fetcher.dart';
import 'flags_store.dart';

class FlagsRepository {
  static const defaultStoreReadTimeout = Duration(milliseconds: 100);

  @visibleForTesting
  static Duration storeReadTimeout = defaultStoreReadTimeout;

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
    final matchingCached =
        cached != null && _contextsMatch(cached.context, context)
            ? cached
            : null;
    if (matchingCached != null) {
      _publishStoredAssignments(requestId, matchingCached);
    }

    await _publishLiveAssignments(
      requestId: requestId,
      context: context,
      liveAssignments: _fetchLiveAssignments(context),
      clearOnFailure: matchingCached == null,
    );
  }

  Future<({PrecomputedAssignments? assignments})> _fetchLiveAssignments(
    FlagsEvaluationContext context,
  ) async {
    try {
      return (assignments: await fetcher.fetch(context));
    } catch (_) {
      return (assignments: null);
    }
  }

  Future<void> _publishLiveAssignments({
    required int requestId,
    required FlagsEvaluationContext context,
    required Future<({PrecomputedAssignments? assignments})> liveAssignments,
    required bool clearOnFailure,
  }) async {
    final result = await liveAssignments;
    final assignments = result.assignments;
    if (assignments != null) {
      await _publishAssignments(
        requestId: requestId,
        context: context,
        assignments: assignments,
      );
      return;
    }

    if (clearOnFailure && requestId == _contextRequestId) {
      _state = null;
    }
  }

  Future<void> _publishAssignments({
    required int requestId,
    required FlagsEvaluationContext context,
    required PrecomputedAssignments assignments,
  }) async {
    if (requestId != _contextRequestId) {
      return;
    }

    final data = FlagsData(
      flags: assignments.flags,
      context: context,
      date: _nextStateDate(),
    );
    _state = data;
    await _writeCached(data);
  }

  void _publishStoredAssignments(int requestId, FlagsData data) {
    if (requestId != _contextRequestId || _isOlderThanCurrentState(data)) {
      return;
    }

    _state = data;
  }

  bool _isOlderThanCurrentState(FlagsData data) {
    final current = _state;
    return current != null &&
        _contextsMatch(current.context, data.context) &&
        data.date.isBefore(current.date);
  }

  DateTime _nextStateDate() {
    final now = dateProvider();
    final current = _state?.date;
    if (current != null && !now.isAfter(current)) {
      return current.add(const Duration(microseconds: 1));
    }
    return now;
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
    final store = this.store;
    if (store == null) {
      return null;
    }

    try {
      final encoded = await store.read(clientName).timeout(
            storeReadTimeout,
            onTimeout: () => null,
          );
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
