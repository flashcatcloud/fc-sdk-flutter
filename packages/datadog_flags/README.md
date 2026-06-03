# Datadog Flags for Flutter

`datadog_flags` is a Dart-native package for Datadog feature flag assignments.
This initial package is unpublished and contains the precompute transport layer
that later stacked PRs will build into a complete Flutter flagging client.

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

## Behavior

- Assignments are fetched with `POST /precompute-assignments`.
- Requests use `Content-Type: application/vnd.api+json` and
  `dd-client-token`.
- `dd-application-id` is included only when configured.
- Gov sites fall back to the US1 flags endpoint, matching the iOS SDK behavior.
- Unknown or malformed individual flag assignments are ignored so one bad flag
  does not prevent other assignments from loading.

## Local Validation

From this package:

```bash
dart analyze .
dart test
```

The included request example can make a real precompute call:

```bash
DD_CLIENT_TOKEN=<client-token> \
DD_ENV=staging \
DD_TARGETING_KEY=test-subject \
dart run example/precompute_request.dart
```
