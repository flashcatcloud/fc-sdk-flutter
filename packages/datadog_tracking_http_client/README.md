# FlashCat Tracking HTTP Client for Flutter

> Forked from the [Datadog Flutter SDK](https://github.com/DataDog/dd-sdk-flutter) and customized for FlashCat Cloud. Only the published package name changes (`flashcat_tracking_http_client`); internal namespaces remain `datadog*`. See [`flashcat_flutter_plugin`][1] for the full list of differences.

## Overview

A plugin for use with the [`flashcat_flutter_plugin`][1], used to track performance of HTTP calls as RUM resources and enable Distributed Tracing.

## Getting started

To use this plugin, enable it during configuration of your SDK. In order to enable Distributed Tracing, you also need to set the `firstPartyHosts` property in your configuration object.

```dart
import 'package:flashcat_tracking_http_client/flashcat_tracking_http_client.dart';

final configuration = DatadogConfiguration(
  // configuration
  firstPartyHosts: ['example.com'],
)..enableHttpTracking()
```

Note that the Tracking HTTP Client modifies `[HttpOverrides.global]()`. If you need to provide your own `HttpOverrides`, make sure to initialize it prior to initializing the SDK. During initialization, the SDK will check the value of `HttpOverrides.current` and use this for client creation if it exists.

## Using http.Client wrapping

This package also supplies a composable client usable with the [http pub package](https://pub.dev/packages/http) called `DatadogClient`. For most scenarios, we recommend you use the HTTP tracking method above, but there are a few scenarios where using `DatadogClient` might make more sense:

* If you are using native HTTP libraries like [`cronet_http`](https://pub.dev/packages/cronet_http) or [`cupertino_http`](https://pub.dev/packages/cupertino_http), which do not work with the above tracking method.
* If you only want to track specific resource requests.

If you are using `cronet_http` or `cupertino_http`, you can combine `DatadogClient` with the above tracking method. Otherwise, the two methods may interfere with each other.

To use the `DatadogClient`, create and compose the `Client` from the `http` package:

```dart
import 'package:flashcat_tracking_http_client/flashcat_tracking_http_client.dart';
import 'package:http/http.dart' as http;

final configuration = DatadogConfiguration(
  // specifying firstPartyHosts is still necessary to
  // enable distributed tracing
  firstPartyHosts: ['example.com'],
)

final httpClient = http.Client()
final datadogClient = DatadogClient(datadogSdk: DatadogSdk.instance, innerClient: httpClient);
```

The `innerClient` parameter is optional. If it is not supplied, DatadogClient will create a `Client` for you with default options.

# Contributing

Pull requests are welcome. First, open an issue to discuss what you would like to change. For more information, read the [contributing guide](../../CONTRIBUTING.md) in the root repository.

# License

[Apache License, v2.0](LICENSE)

[1]: https://pub.dev/packages/flashcat_flutter_plugin
