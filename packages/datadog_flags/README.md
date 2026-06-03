# Datadog Flags

`datadog_flags` is the native Dart SDK for Datadog Feature Flags and
Experimentation in client applications. It lets applications evaluate
Datadog-backed feature flags from precomputed assignments, resolve typed values
locally, and report exposure and flag evaluation events.

This package does not bridge to native iOS or Android flagging SDKs.

## Typed Evaluation

Enable Datadog Flags, initialize a client with an evaluation context, and
evaluate typed details from the current assignment state:

```dart
final datadogFlags = DatadogFlags.instance;

await datadogFlags.enable(
  configuration: DatadogFlagsConfiguration(
    datadogConfig: const DatadogFlagsConfig(
      clientToken: 'pub...',
      env: 'staging',
      site: DatadogFlagsSite.us1,
    ),
  ),
);

final flags = datadogFlags.sharedClient();
await flags.initialize(
  const FlagsEvaluationContext(targetingKey: 'user-123'),
);

final details = flags.getBooleanDetails(
  key: 'checkout.enabled',
  defaultValue: false,
);
final enabled = details.value;
```

## Multiple Contexts and Isolates

Use separate clients for different mobile subjects, such as logged-out and
logged-in users or org-level and user-level targeting:

```dart
final orgFlags = datadogFlags.sharedClient(name: 'org');
await orgFlags.initialize(
  const FlagsEvaluationContext(targetingKey: 'org-123'),
);

final userFlags = datadogFlags.sharedClient(name: 'user');
await userFlags.initialize(
  const FlagsEvaluationContext(targetingKey: 'user-456'),
);
```

Clients are local to the Dart isolate where they are created. Background
isolates do not share `DatadogFlags` state or client assignment caches with the
main isolate, so each background isolate must call
`DatadogFlags.instance.enable()`, create the clients it needs, and initialize
them independently.

## Behavior

- Assignments are fetched with `POST /precompute-assignments`.
- Requests use `Content-Type: application/vnd.api+json` and `dd-client-token`.
- `dd-application-id` is included only when configured.
- Gov sites fall back to the US1 flags endpoint, matching the iOS SDK behavior.
- Unknown or malformed individual flag assignments are ignored so that one
  invalid assignment does not prevent other assignments from loading.
- Typed evaluations return caller-provided defaults instead of throwing when
  assignments are unavailable, a flag is missing, or a flag has the wrong type.
- Typed details include provider-not-ready, flag-not-found, or type-mismatch
  errors when default values are used.
- Successful typed evaluations emit exposure events when exposure tracking is
  enabled and the assignment has `doLog: true`, deduped by targeting key, flag
  key, allocation, and variant.
- Successful, defaulted, and error evaluations are aggregated into flag
  evaluation events and sent on `shutdown()` or the configured batch boundary.
- Last-known successful assignments are restored only when the stored context
  matches the active evaluation context.
