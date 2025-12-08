// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2025-Present Datadog, Inc.

import 'dart:ffi' as ffi;

import 'package:ffi/ffi.dart';

import '../../datadog_internal.dart';

final class _DatadogCContext extends ffi.Struct {
  external ffi.Pointer<Utf8> sessionId;
  external ffi.Pointer<Utf8> accountId;
  external ffi.Pointer<Utf8> userId;
}

class IosPlatformBridge {
  static DatadogContext? getContext() {
    // Instead of using Objective-C interop, we're going to use straight C / Swift interop
    // to avoid pulling in the Objective-C package as part of Core.
    final cContext = _getDatadogContext();

    // If all three are null, just return null
    if (cContext.sessionId == ffi.nullptr &&
        cContext.accountId == ffi.nullptr &&
        cContext.userId == ffi.nullptr) {
      return null;
    }

    String? sessionId;
    if (cContext.sessionId != ffi.nullptr) {
      sessionId = cContext.sessionId.toDartString();
      malloc.free(cContext.sessionId);
    }
    String? accountId;
    if (cContext.accountId != ffi.nullptr) {
      accountId = cContext.accountId.toDartString();
      malloc.free(cContext.accountId);
    }
    String? userId;
    if (cContext.userId != ffi.nullptr) {
      userId = cContext.userId.toDartString();
      malloc.free(cContext.userId);
    }

    return DatadogContext(
        sessionId: sessionId, userId: userId, accountId: accountId);
  }
}

@ffi.Native<_DatadogCContext Function()>(
    isLeaf: true, symbol: 'flutterGetDatadogContext')
external _DatadogCContext _getDatadogContext();
