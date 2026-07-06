# FlashCat WebView Tracking for Flutter

> Forked from the [Datadog Flutter SDK](https://github.com/DataDog/dd-sdk-flutter) and customized for FlashCat Cloud. Only the published package name changes (`flashcat_webview_tracking`); internal namespaces remain `datadog*`. See [`flashcat_flutter_plugin`][1] for the full list of differences.

## Overview

This package is an extension to the [`flashcat_flutter_plugin`][1]. It allows
Real User Monitoring to monitor web views and eliminate blind spots in your hybrid Flutter applications.

## Instrumenting your web views

The RUM Flutter SDK provides APIs for you to control web view tracking when using the [`webview_flutter`][2] package.

Add both the `flashcat_webview_tracking` package and the `webview_flutter` package to your `pubspec.yaml`:

```yaml
dependencies:
  webview_flutter: ^4.0.4
  flashcat_flutter_plugin: ^0.1.0
  flashcat_webview_tracking: ^0.1.0
```

To add Web View Tracking, call the `trackDatadogEvents` extension method on `WebViewController`, providing the list of allowed hosts.

For example:

```dart
import 'package:flashcat_flutter_plugin/flashcat_flutter_plugin.dart';
import 'package:flashcat_webview_tracking/flashcat_webview_tracking.dart';

webViewController = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..trackDatadogEvents(
    DatadogSdk.instance,
    ['myapp.example'],
  )
  ..loadRequest(Uri.parse('myapp.example'));
```

Note that `JavaScriptMode.unrestricted` is required for tracking to work on Android.

[1]: https://pub.dev/packages/flashcat_flutter_plugin
[2]: https://pub.dev/packages/webview_flutter
