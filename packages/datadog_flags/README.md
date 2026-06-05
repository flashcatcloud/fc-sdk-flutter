# Datadog Flags

`datadog_flags` is the native Dart SDK for Datadog Feature Flags and
Experimentation in client applications. It lets applications evaluate
Datadog-backed feature flags.

## Typed Evaluation

Enable the client, set an evaluation context, and evaluate typed values from the
current assignment state:

```dart
await DatadogFlags.enable(
  configuration: DatadogFlagsConfiguration(
    datadogContext: const DatadogFlagsContext(
      clientToken: 'pub...',
      env: 'staging',
      site: DatadogFlagsSite.us1,
    ),
  ),
);

final flags = DatadogFlags.sharedClient();
await flags.setEvaluationContext(
  const FlagsEvaluationContext(targetingKey: 'user-123'),
);

final enabled = flags.getBooleanValue(
  key: 'checkout.enabled',
  defaultValue: false,
);
```

## Behavior

- Unknown or malformed individual flag assignments are ignored so one bad flag
  does not prevent other assignments from loading.
- Typed evaluations return caller-provided defaults instead of throwing when
  assignments are unavailable, a flag is missing, or a flag has the wrong type.
- Typed details include provider-not-ready, flag-not-found, or type-mismatch
  errors when defaults are used.

## Local Validation

From this package:

```bash
dart analyze .
dart test
```

The included typed evaluation example can run against Datadog:

```bash
DD_CLIENT_TOKEN=<client-token> \
DD_ENV=staging \
DD_TARGETING_KEY=test-subject \
DD_FLAG_KEY=checkout.enabled \
DD_FLAG_TYPE=boolean \
dart run example/typed_evaluation.dart
```
