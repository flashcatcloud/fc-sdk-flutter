# Datadog Flags

`datadog_flags` is the native Dart SDK for Datadog Feature Flags and
Experimentation in client applications. It lets applications evaluate
Datadog-backed feature flags.

## Typed Evaluation

Enable the client, set an evaluation context, and evaluate typed values from the
current assignment state:

```dart
final datadogFlags = DatadogFlags.instance;

await datadogFlags.enable(
  configuration: DatadogFlagsConfiguration(
    datadogContext: const DatadogFlagsContext(
      clientToken: 'pub...',
      env: 'staging',
      site: DatadogFlagsSite.us1,
    ),
  ),
);

final flags = datadogFlags.sharedClient();
await flags.setEvaluationContext(
  const FlagsEvaluationContext(targetingKey: 'user-123'),
);

final enabled = flags.getBooleanValue(
  key: 'checkout.enabled',
  defaultValue: false,
);
```

## Multiple Contexts and Isolates

Use separate clients for different mobile subjects, such as logged-out and
logged-in users or org-level and user-level targeting:

```dart
final orgFlags = datadogFlags.sharedClient(name: 'org');
await orgFlags.setEvaluationContext(
  const FlagsEvaluationContext(targetingKey: 'org-123'),
);

final userFlags = datadogFlags.sharedClient(name: 'user');
await userFlags.setEvaluationContext(
  const FlagsEvaluationContext(targetingKey: 'user-456'),
);
```

Clients are local to the Dart isolate where they are created. Background
isolates do not share `DatadogFlags` state or client assignment caches with the
main isolate, so each background isolate must call
`DatadogFlags.instance.enable()`, create the clients it needs, and set
evaluation contexts independently.

## Behavior

- Unknown or malformed individual flag assignments are ignored so that one
  invalid assignment does not prevent other assignments from loading.
- Typed evaluations return caller-provided defaults instead of throwing when
  assignments are unavailable, a flag is missing, or a flag has the wrong type.
- Typed details include provider-not-ready, flag-not-found, or type-mismatch
  errors when default values are used.
