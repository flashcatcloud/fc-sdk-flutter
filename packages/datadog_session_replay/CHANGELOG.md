# Changelog

## 1.0.0-preview.1

* Initial release of Datadog Session Replay with the following features:
    * Capture containers, text, images, icons, and touches.
    * Support for masking sensitive data, including masking all user input or sensitive input fields.
    * Support for "fine grained" text, image, and touch masking with `SessionReplayPrivacy` widget.
* The follow features are not supported in this preview:
    * Hybrid Session Replay
        * Native iOS and Android applications with Flutter views are not currently supported.
        * Flutter applications with native view are not currently supported.
        * Capture of Web Views is not currently supported.
    * Certain simple Material / Cupertino widgets are not captured.
    * Text from RichText widgets is captured, but only use the top most text style.
    * Flutter Web is not currently supported.
    * Manual recording is not currently supported.