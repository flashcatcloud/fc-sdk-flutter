// Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
// This product includes software developed at Datadog (https://www.datadoghq.com/).
// Copyright 2023-Present Datadog, Inc.

import 'dart:math';

import '../../flashcat_flutter_plugin.dart';

/// Defines the frequency at which Datadog SDK will collect mobile vitals, such
/// as CPU and memory usage.
enum VitalsFrequency {
  /// Collect mobile vitals every 100ms.
  frequent,

  /// Collect mobile vitals every 500ms.
  average,

  /// Collect mobile vitals every 1000ms.
  rare,
}

/// A function that allows you to modify specific [RumViewEvent]s before they
/// are sent to Datadog.
///
/// The [RumViewEventMapper] can modify any mutable (non-final) properties in
/// the [RumViewEvent]
typedef RumViewEventMapper = RumViewEvent Function(RumViewEvent event);

/// A function that allows you to modify or drop specific [RumActionEvent]s before
/// they are sent to Datadog.
///
/// The [RumActionEventMapper] can modify any mutable (non-final) properties in the
/// [RumActionEvent]
typedef RumActionEventMapper = RumActionEvent? Function(RumActionEvent event);

/// A function that allows you to modify or drop specific [RumResourceEvent]s before
/// they are sent to Datadog.
///
/// The [RumResourceEventMapper] can modify any mutable (non-final) properties in the
/// [RumResourceEvent]
typedef RumResourceEventMapper = RumResourceEvent? Function(
    RumResourceEvent event);

/// A function that allows you to modify or drop specific [RumErrorEvent]s before
/// they are sent to Datadog.
///
/// The [RumErrorEventMapper] can modify any mutable (non-final) properties in the
/// [RumErrorEvent]
typedef RumErrorEventMapper = RumErrorEvent? Function(RumErrorEvent event);

/// A function that allows you to modify or drop specific [RumLongTaskEvent]s before
/// they are sent to Datadog.
///
/// The [RumLongTaskEvent] can modify any mutable (non-final) properties in the
/// [RumLongTaskEvent]
typedef RumLongTaskEventMapper = RumLongTaskEvent? Function(
    RumLongTaskEvent event);

/// A function that allows you to modify or drop specific [RumVitalOperationEvent]s before
/// they are sent to Datadog.
///
/// The [RumVitalOperationEvent] can modify any mutable (non-final) properties in the
/// [RumVitalOperationEvent]
typedef RumVitalOperationEventMapper = RumVitalOperationStepEvent? Function(
    RumVitalOperationStepEvent event);

/// The context provided to [RumBeforeSamplingCallback] before a new RUM
/// session is sampled.
class RumBeforeSamplingContext {
  /// The sampling rate that would otherwise be used for the new session.
  final double sessionSampleRate;

  /// Custom values supplied by remote configuration, when available.
  final Map<String, Object?>? custom;

  const RumBeforeSamplingContext({
    required this.sessionSampleRate,
    this.custom,
  });
}

/// Called synchronously before a new RUM session is sampled.
///
/// Return a value between `0.0` and `100.0` to override the sampling rate, or
/// `null` to keep [RumBeforeSamplingContext.sessionSampleRate]. Invalid values
/// and exceptions are ignored by the SDK.
typedef RumBeforeSamplingCallback = double? Function(
  RumBeforeSamplingContext context,
);

/// Configuration options for the Datadog Real User Monitoring (RUM) feature.
class DatadogRumConfiguration {
  // Either a RUM Application Id. Obtained on the Datadog website.
  String applicationId;

  /// Sets the sampling rate for RUM Sessions.
  ///
  /// The sampling rate must be a value between `0.0` and `100.0`. A value of
  /// `0.0` means no session is collected by this rate, `100.0` means all
  /// sessions are collected. With [sessionOnError], the sessions this rate
  /// leaves out are still uploaded if they report an error.
  ///
  /// Defaults to `100.0`.
  double sessionSamplingRate;

  /// Also keep the sessions [sessionSamplingRate] does not keep, but only
  /// those that report an error.
  ///
  /// Such a session is collected in memory without uploading anything, keeping
  /// up to its last minute of events. If it reports an error, what was kept is
  /// uploaded and the session carries on like any collected one; if it ends
  /// without one, nothing of it is ever sent. [DatadogRum.setForcedSession]
  /// releases what was kept for upload right away, error or not. A native
  /// crash is reported at the next launch with its last view, without the
  /// minute before it. Such a session reports a session sample rate of `0`,
  /// since it stands for itself rather than for the sessions a rate would
  /// imply.
  ///
  /// Any RUM error counts, whether reported through [DatadogSdk.runApp],
  /// [DatadogRum.handleFlutterError], [DatadogRum.addError],
  /// [DatadogRum.addErrorInfo], [DatadogRum.stopResourceWithError] or
  /// [DatadogRum.stopResourceWithErrorInfo], unless [errorEventMapper] drops
  /// it. A resource that completes with an HTTP error status is not an error
  /// by itself. A [beforeSampling] returning `0` turns this off for that
  /// session. With [remoteConfigurationEnabled], a value the console sets
  /// takes precedence over this one.
  ///
  /// Defaults to `false`.
  bool sessionOnError;

  /// Sets the sampling rate for resource tracing
  ///
  /// The sampling rate must be a value between `0.0` and `100.0`. A value of
  /// `0.0` means no resources will include APM tracing, `100.0` resource will
  /// include APM tracing
  ///
  /// Defaults to `100.0`.
  double traceSampleRate;

  /// The strategy for injecting trace context into requests. See [TraceContextInjection].
  ///
  /// Defaults to [TraceContextInjection.sampled].
  TraceContextInjection traceContextInjection = TraceContextInjection.sampled;

  /// Enable or disable detection of "long tasks"
  ///
  /// Long task detection attempts to detect when an application is doing too
  /// much work on the main isolate, or on the main native thread, which could
  /// prevent your app from rendering at a smooth framerate.
  ///
  /// Defaults to true.
  bool detectLongTasks;

  /// The amount of elapsed time that is considered to be a "long task", in
  /// seconds.
  ///
  /// If the main isolate takes more than [longTaskThreshold] seconds to process
  /// a microtask, it will appear as a Long Task in Datadog RUM Explorer. This
  /// has a minimum of 0.02 seconds.
  ///
  /// The Datadog iOS and Android SDKs will also report if their main threads
  /// are stalled for longer than this threshold, and will also appear as a Long
  /// Task in the Datadog RUM Explorer
  ///
  /// Note -- this argument is ignored on Flutter Web, which always uses a value
  /// of 0.05 seconds (50ms).  See documentation on [RUM Browser
  /// Monitoring](https://docs.datadoghq.com/real_user_monitoring/browser/data_collected/)
  ///
  /// Defaults to 0.1 seconds
  double longTaskThreshold;

  bool trackFrustrations;

  /// Sets the preferred frequency for collecting mobile vitals.
  ///
  /// Note this setting does not affect the sampling done by [reportFlutterPerformance].
  /// Assign to `null` to disable mobile vitals collection.
  ///
  /// Defaults to [VitalsFrequency.average].
  VitalsFrequency? vitalUpdateFrequency;

  /// Whether to report Flutter specific performance metrics (build and raster
  /// times)
  ///
  /// This uses the [SchedulerBinding.addTimingsCallback] method to report build
  /// and raster times for views, and has a documented negligible impact on
  /// performance.
  ///
  /// Defaults to false
  bool reportFlutterPerformance = false;

  /// Whether to track non-fatal ANRs (Application Not Responding) errors as RUM
  /// errors.
  ///
  /// This option is specific to Android.
  ///
  /// By default, the reporting of non-fatal ANRs on Android 30+ is disabled
  /// because it would create too much noise over fatal ANRs. On Android 29 and
  /// below, however, the reporting of non-fatal ANRs is enabled by default, as
  /// fatal ANRs cannot be reported on those versions.
  bool? trackNonFatalAnrs;

  /// Set the threshold for reporting for non-fatal app hangs in seconds.
  ///
  /// This options is specific to iOS.
  ///
  /// App hangs are a type of error that occurs when the application is
  /// unresponsive for too long. Set the parameter to the minimal duration you
  /// want app hangs to be reported. For example, enter 0.25 to report hangs
  /// lasting at least 250 milliseconds. See [Configure the app hang
  /// threshold](https://docs.datadoghq.com/real_user_monitoring/error_tracking/mobile/ios/?tab=cocoapods#configure-the-app-hang-threshold)
  /// for more guidance on what to set this value to.
  ///
  /// Defaults to disabled (`null`).
  double? appHangThreshold;

  /// Enables collection of anonymous user ID across sessions.
  ///
  /// When enabled, the SDK generates a unique, non-personal anonymous user ID that is persisted across
  /// app launches. This ID will be attached to each RUM Session, allowing you to link sessions
  /// originating from the same user/device without collecting personal data.
  ///
  /// Defaults to `true`.
  bool trackAnonymousUser = true;

  /// Whether to track RUM events when no view is active, including when the app is in the background.
  ///
  /// When enabled, RUM will attach events (such as crashes and network requests) to an automatically
  /// created "background" view. This includes events that occur when the application is in the background.
  ///
  /// Note: Enabling this option may result in additional sessions, which could impact billing.
  ///
  /// Defaults to `false`.
  bool trackBackgroundEvents;

  /// The amount of time after a view starts where a Resource should be
  /// considered when calculating Time to Network-Settled (TNS). TNS will be
  /// calculated using all resources that start withing the specified threshold,
  /// in seconds.
  ///
  /// Defaults to 0.1 seconds.
  double initialResourceThreshold;

  /// Use a custom endpoint for sending RUM data.
  String? customEndpoint;

  /// Whether the native SDK may retrieve RUM sampling configuration remotely.
  ///
  /// This is disabled by default. Enabling it may cause the native SDK to make
  /// configuration requests. Remote configuration affects sessions created
  /// after the configuration is received.
  bool remoteConfigurationEnabled;

  /// A callback that can override the sampling rate for each new session.
  ///
  /// This callback is independent of [remoteConfigurationEnabled]. When remote
  /// configuration is disabled, it still receives the locally configured
  /// [sessionSamplingRate] and `custom` is `null`.
  RumBeforeSamplingCallback? beforeSampling;

  //
  double telemetrySampleRate;

  /// A function that allows you to modify or drop specific [RumViewEvent]s
  /// before they are sent to Datadog.
  RumViewEventMapper? viewEventMapper;

  /// A function that allows you to modify or drop specific [RumActionEvent]s
  /// before they are sent to Datadog.
  RumActionEventMapper? actionEventMapper;

  /// A function that allows you to modify or drop specific [RumResourceEvent]s
  /// before they are sent to Datadog.
  RumResourceEventMapper? resourceEventMapper;

  /// A function that allows you to modify or drop specific [RumResourceEvent]s
  /// before they are sent to Datadog.
  RumErrorEventMapper? errorEventMapper;

  /// A function that allows you to modify or drop specific [RumLongTaskEvent]s
  /// before they are sent to Datadog.
  RumLongTaskEventMapper? longTaskEventMapper;

  /// A function that allows you to modify or drop specific
  /// [RumVitalOperationEvent]s before they are sent to Datadog.
  RumVitalOperationEventMapper? vitalOperationStepEventMapper;

  Map<String, Object?> additionalConfig;

  DatadogRumConfiguration({
    required this.applicationId,
    double sessionSamplingRate = 100.0,
    this.sessionOnError = false,
    double traceSampleRate = 100.0,
    this.traceContextInjection = TraceContextInjection.sampled,
    this.detectLongTasks = true,
    double longTaskThreshold = 0.1,
    this.trackFrustrations = true,
    this.vitalUpdateFrequency = VitalsFrequency.average,
    this.reportFlutterPerformance = false,
    this.trackNonFatalAnrs,
    this.appHangThreshold,
    this.trackAnonymousUser = true,
    this.trackBackgroundEvents = false,
    this.initialResourceThreshold = 0.1,
    this.customEndpoint,
    this.remoteConfigurationEnabled = false,
    this.beforeSampling,
    this.telemetrySampleRate = 20.0,
    this.viewEventMapper,
    this.actionEventMapper,
    this.resourceEventMapper,
    this.errorEventMapper,
    this.longTaskEventMapper,
    this.vitalOperationStepEventMapper,
    this.additionalConfig = const <String, Object>{},
  })  : sessionSamplingRate = max(0, min(sessionSamplingRate, 100)),
        traceSampleRate = max(0, min(traceSampleRate, 100)),
        longTaskThreshold = max(0.02, longTaskThreshold);

  Map<String, Object?> encode() {
    return {
      'applicationId': applicationId,
      'sessionSampleRate': sessionSamplingRate,
      'sessionOnError': sessionOnError,
      'detectLongTasks': detectLongTasks,
      'longTaskThreshold': longTaskThreshold,
      'trackFrustrations': trackFrustrations,
      'vitalsUpdateFrequency': vitalUpdateFrequency.toString(),
      'reportFlutterPerformance': reportFlutterPerformance,
      'trackNonFatalAnrs': trackNonFatalAnrs,
      'appHangThreshold': appHangThreshold,
      'trackAnonymousUser': trackAnonymousUser,
      'trackBackgroundEvents': trackBackgroundEvents,
      'initialResourceThreshold': initialResourceThreshold,
      'customEndpoint': customEndpoint,
      'remoteConfigurationEnabled': remoteConfigurationEnabled,
      'attachBeforeSampling': beforeSampling != null,
      'telemetrySampleRate': telemetrySampleRate,
      'attachViewEventMapper': viewEventMapper != null,
      'attachActionEventMapper': actionEventMapper != null,
      'attachResourceEventMapper': resourceEventMapper != null,
      'attachErrorEventMapper': errorEventMapper != null,
      'attachLongTaskEventMapper': longTaskEventMapper != null,
      'attachVitalOperationStepEventMapper':
          vitalOperationStepEventMapper != null,
      'additionalConfig': additionalConfig,
    };
  }
}
