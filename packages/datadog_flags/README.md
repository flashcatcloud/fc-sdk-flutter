# Datadog Flags for Flutter

`datadog_flags` is a Dart-native package for Datadog feature flag assignments.
This package is unpublished while the stacked MVP is being assembled. It
currently contains precompute transport, typed local evaluation, and RUM feature
flag reporting.

This package does not bridge to native iOS or Android flagging SDKs.

## Precompute Fetching

Create a Datadog context, an evaluation context, and fetch assignments from the
precompute API:

```dart
final fetcher = FlagAssignmentsFetcher(
  datadogContext: const DatadogFlagsContext(
    clientToken: 'pub...',
    env: 'staging',
    site: DatadogFlagsSite.us1,
  ),
  configuration: const DatadogFlagsConfiguration(),
  httpClient: http.Client(),
);

final assignments = await fetcher.fetch(
  const DatadogFlagsEvaluationContext(
    targetingKey: 'user-123',
    attributes: {'plan': 'pro'},
  ),
);
```

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
  const DatadogFlagsEvaluationContext(targetingKey: 'user-123'),
);

final enabled = flags.getBooleanValue(
  key: 'checkout.enabled',
  defaultValue: false,
);
```

## Behavior

- Assignments are fetched with `POST /precompute-assignments`.
- Requests use `Content-Type: application/vnd.api+json` and
  `dd-client-token`.
- `dd-application-id` is included only when configured.
- Gov sites fall back to the US1 flags endpoint, matching the iOS SDK behavior.
- Unknown or malformed individual flag assignments are ignored so one bad flag
  does not prevent other assignments from loading.
- Typed details return provider-not-ready, flag-not-found, or type-mismatch
  errors when defaults are used.
- Successful typed evaluations report RUM feature flag evaluations when RUM is
  available.
- Successful typed evaluations emit exposure events when the assignment has
  `doLog: true`, deduped by targeting key, flag key, allocation, and variant.

## Local Validation

From this package:

```bash
flutter analyze .
flutter test test
```

The included request example can make a real precompute call:

```bash
DD_CLIENT_TOKEN=<client-token> \
DD_ENV=staging \
DD_TARGETING_KEY=test-subject \
dart run example/precompute_request.dart
```
