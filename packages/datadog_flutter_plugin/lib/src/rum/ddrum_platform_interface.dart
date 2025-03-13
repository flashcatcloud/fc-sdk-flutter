// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2019-2021 Datadog, Inc.

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import '../../datadog_flutter_plugin.dart';
import 'ddrum_method_channel.dart';

abstract class DdRumPlatform extends PlatformInterface {
  DdRumPlatform() : super(token: _token);

  static final Object _token = Object();

  static DdRumPlatform _instance = DdRumMethodChannel();

  static DdRumPlatform get instance => _instance;

  static set instance(DdRumPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> enable(DatadogSdk core, DatadogRumConfiguration configuration);
  Future<void> deinitialize();

  Future<String?> getCurrentSessionId();

  Future<void> startView(DateTime timeStamp, String key, String name,
      Map<String, Object?> attributes);
  Future<void> stopView(
      DateTime timeStamp, String key, Map<String, Object?> attributes);
  Future<void> addTiming(DateTime timeStamp, String name);
  Future<void> addViewLoadingTime(bool overwrite);

  Future<void> startResource(DateTime timeStamp, String key,
      RumHttpMethod httpMethod, String url, Map<String, Object?> attributes);
  Future<void> stopResource(DateTime timeStamp, String key, int? statusCode,
      RumResourceType kind, int? size, Map<String, Object?> attributes);
  Future<void> stopResourceWithError(DateTime timeStamp, String key,
      Exception error, Map<String, Object?> attributes);
  Future<void> stopResourceWithErrorInfo(DateTime timeStamp, String key,
      String message, String type, Map<String, Object?> attributes);

  Future<void> addError(
    DateTime timeStamp,
    Object error,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  );
  Future<void> addErrorInfo(
    DateTime timeStamp,
    String message,
    RumErrorSource source,
    StackTrace? stackTrace,
    String? errorType,
    Map<String, Object?> attributes,
  );

  Future<void> addAction(DateTime timeStamp, RumActionType type, String name,
      Map<String, Object?> attributes);
  Future<void> startAction(DateTime timeStamp, RumActionType type, String name,
      Map<String, Object?> attributes);
  Future<void> stopAction(DateTime timeStamp, RumActionType type, String name,
      Map<String, Object?> attributes);

  Future<void> addAttribute(String key, dynamic value);
  Future<void> removeAttribute(String key);
  Future<void> setInternalViewAttribute(String key, Object value);

  Future<void> addFeatureFlagEvaluation(String name, Object value);
  Future<void> stopSession();

  Future<void> reportLongTask(DateTime at, int durationMs);
  Future<void> updatePerformanceMetrics(
      List<double> buildTimes, List<double> rasterTimes);
}
