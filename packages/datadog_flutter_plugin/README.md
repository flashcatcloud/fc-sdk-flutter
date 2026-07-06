# FlashCat SDK for Flutter

> Flutter plugin for FlashCat Real User Monitoring (RUM), crash reporting, and WebView tracking.

## About

This SDK is forked from the [Datadog Flutter SDK](https://github.com/DataDog/dd-sdk-flutter) and customized for FlashCat Cloud. It is a thin bridge over the FlashCat native SDKs ([iOS](https://github.com/flashcatcloud/fc-sdk-ios), [Android](https://github.com/flashcatcloud/fc-sdk-android)).

### Key Differences from the Datadog SDK

- **Endpoint**: Data is sent to FlashCat Cloud (`browser.flashcat.cloud`) instead of Datadog.
- **Site configuration**: Uses `FlashcatSite` with `.cn` (default) and `.staging`, replacing `DatadogSite`.
- **Package name**: Published as `flashcat_flutter_plugin` and `flashcat_webview_tracking`; imports use `package:flashcat_flutter_plugin/…`. Only the published package name changes — internal Dart/Kotlin/Swift namespaces remain `datadog*`.
- **Native dependencies**: Uses the FlashCat forks — iOS `Flashcat*` pods / `fc-sdk-ios` (SPM), Android `cloud.flashcat:*`.
- **v1 scope**: iOS and Android only; the Flutter Web target is dropped.
- **Not yet available**: `Logs` (the API is a no-op — FlashCat ingest does not accept Logs yet), Session Replay, automatic HTTP/resource tracking (`datadog_tracking_http_client`), the dio/gql/grpc integrations, and Feature Flags.

---

## Overview

FlashCat Real User Monitoring (RUM) enables you to visualize and analyze the real-time performance and user journeys of your Flutter application’s individual users.

This release requires Flutter 3.27+ and supports iOS and Android only.

## Native SDK Versions

| iOS SDK | Android SDK |
| :-----: | :---------: |
| 0.5.0 | 0.4.1 |

### iOS

Your iOS Podfile must have `use_frameworks!` (which is true by default in Flutter) and target iOS version >= 13.0.

### Android

On Android, your `minSdkVersion` must be >= 23, and if you are using Kotlin, it should be version >= 2.1.0.

## Setup

Use the [FlashCat Flutter Plugin][1] to set up Real User Monitoring (RUM) and crash reporting.


### Create configuration object

Create a configuration object for each FlashCat feature (such as RUM) with the following snippet. By not passing a configuration for a given feature, it is disabled.

```dart
// Determine the user's consent to be tracked
final trackingConsent = ...
final configuration = DatadogConfiguration(
  clientToken: '<CLIENT_TOKEN>',
  env: '<ENV_NAME>',
  site: FlashcatSite.cn,
  nativeCrashReportEnabled: true,
  rumConfiguration: DatadogRumConfiguration(
    applicationId: '<RUM_APPLICATION_ID>',
  )
);
```

For more information on available configuration options, see the [DatadogConfiguration object][8] documentation.

### Initialize the library

You can initialize RUM using one of two methods in the `main.dart` file.

1. Use `DatadogSdk.runApp`, which automatically sets up error reporting.

   ```dart
   await DatadogSdk.runApp(configuration, () async {
     runApp(const MyApp());
   })
   ```

2. Alternatively, you can manually set up error tracking and resource tracking. Because `DatadogSdk.runApp` calls `WidgetsFlutterBinding.ensureInitialized`, if you are not using `DatadogSdk.runApp`, you need to call this method prior to calling `DatadogSdk.instance.initialize`.

  ```dart
  WidgetsFlutterBinding.ensureInitialized();
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    DatadogSdk.instance.rum?.handleFlutterError(details);
    originalOnError?.call(details);
  };
  final platformOriginalOnError = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (e, st) {
    DatadogSdk.instance.rum?.addErrorInfo(
      e.toString(),
      RumErrorSource.source,
      stackTrace: st,
    );
    return platformOriginalOnError?.call(e, st) ?? false;
  };
  await DatadogSdk.instance.initialize(configuration);

  runApp(const MyApp());
  ```

### Track RUM views

The Datadog Flutter Plugin can automatically track named routes using the `DatadogNavigationObserver` on your MaterialApp.

```dart
MaterialApp(
  home: HomeScreen(),
  navigatorObservers: [
    DatadogNavigationObserver(DatadogSdk.instance),
  ],
);
```

This works if you are using named routes or if you have supplied a name to the `settings` parameter of your `PageRoute`.

Alternately, you can use the `DatadogRouteAwareMixin` property in conjunction with the `DatadogNavigationObserverProvider` property to start and stop your RUM views automatically. With `DatadogRouteAwareMixin`, move any logic from `initState` to `didPush`.

Note that, by default, `DatadogRouteAwareMixin` uses the name of the widget as the name of the View. However, this **does not work with obfuscated code** as the name of the Widget class is lost during obfuscation. To keep the correct view name, override `rumViewInfo`:

To rename your views or supply custom paths, provide a [`viewInfoExtractor`][10] callback. This function can fall back to the default behavior of the observer by calling `defaultViewInfoExtractor`. For example:

```dart
RumViewInfo? infoExtractor(Route<dynamic> route) {
  var name = route.settings.name;
  if (name == 'my_named_route') {
    return RumViewInfo(
      name: 'MyDifferentName',
      attributes: {'extra_attribute': 'attribute_value'},
    );
  }

  return defaultViewInfoExtractor(route);
}

var observer = DatadogNavigationObserver(
  datadogSdk: DatadogSdk.instance,
  viewInfoExtractor: infoExtractor,
);
```


```dart
class _MyHomeScreenState extends State<MyHomeScreen>
    with RouteAware, DatadogRouteAwareMixin {

  @override
  RumViewInfo get rumViewInfo => RumViewInfo(name: 'MyHomeScreen');
}
```

## Contributing

Pull requests are welcome. First, open an issue to discuss what you would like to change.

For more information, read the [Contributing guidelines][4].

## License

For more information, see [Apache License, v2.0][5].

[1]: https://pub.dev/packages/flashcat_flutter_plugin
[4]: https://github.com/flashcatcloud/fc-sdk-flutter/blob/main/CONTRIBUTING.md
[5]: https://github.com/flashcatcloud/fc-sdk-flutter/blob/main/LICENSE
[8]: https://pub.dev/documentation/flashcat_flutter_plugin/latest/flashcat_flutter_plugin/DatadogConfiguration-class.html
[10]: https://pub.dev/documentation/flashcat_flutter_plugin/latest/flashcat_flutter_plugin/ViewInfoExtractor.html
