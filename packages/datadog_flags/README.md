# Datadog Flags for Flutter

`datadog_flags` is the native Flutter SDK for Datadog Feature Flags and
Experimentation. It lets Flutter applications evaluate Datadog-backed feature
flags without bridging through the native iOS or Android flagging SDKs.

This package does not bridge to native iOS or Android flagging SDKs.

## Status

This package is being introduced in a stack of small reviewable PRs. The first
stack slice creates the package and internal assignment transport used by the
SDK, but the public customer API is the flag evaluation client added by the next
stack slice.

Customer-facing usage documentation will live here once the typed flag
evaluation API lands.

## Behavior

- Native Dart implementation for Flutter applications.
- No runtime bridge to the native iOS or Android flagging SDKs.
- Designed for Datadog Feature Flags and Experimentation, including local typed
  flag evaluation and SDK telemetry in later stack slices.
- Supports Datadog US1 staging for dogfooding and local validation.

## Local Validation

From this package:

```bash
dart analyze .
dart test
```
