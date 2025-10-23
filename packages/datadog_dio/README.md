
# Datadog Dio integration

> A package for use with Dio and the Datadog SDK, used tro track performance of HTTP calls and enable Datadog Distributed Tracing.

## Getting started

To use this plugin, enable it during configuration of your SDK. In order to enable Datadog Distributed Tracing, you also need to set the `firstPartyHosts` property in your configuration object.

```dart
import 'package:datadog_tracking_http_client/datadog_tracking_http_client.dart';

final configuration = DatadogConfiguration(
  // configuration
  firstPartyHosts: ['example.com'],
)
```