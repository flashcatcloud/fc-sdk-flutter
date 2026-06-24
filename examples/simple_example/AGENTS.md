# Simple Example Agent Notes

This app is public example code. Keep it safe to publish and easy to run locally.

## Credentials

- Never commit real Datadog client tokens, application IDs, customer names, org names, or customer-owned flag keys.
- Runtime credentials should come from the generated local `.env` file. Use
  `--dart-define` only for optional flag-demo overrides such as `FLAGS_*`.
- Keep `.env` ignored and local-only. It must not be committed.
- Prefer placeholder values in docs and tests, for example `pub...`, `fake-token`, or `fake-application-id`.

## Flags Example

- The default flags screen should use Datadog FFE dogfooding placeholders only.
- Custom/customer validation must be opt-in through `FLAGS_CUSTOM_*` `--dart-define` values.
- Do not hardcode customer-specific modes, labels, targeting attributes, or flag keys in Dart source.
- Do not add a fake local mode for flags. When credentials are provided, the example should exercise real Datadog Flags requests.
- Keep diagnostics compact. Timing, payload size, and event counters are useful, but should not dominate the example UI.

## Local Run Shape

Generate local configuration before running the app:

```bash
../../generate_env.sh
flutter run
```

For private custom validation, add local-only values:

```bash
flutter run \
  --dart-define FLAGS_CUSTOM_CLIENT_TOKEN=pub... \
  --dart-define FLAGS_CUSTOM_ENV=prod \
  --dart-define FLAGS_CUSTOM_SITE=us1 \
  --dart-define FLAGS_MODE=custom \
  --dart-define FLAGS_CUSTOM_STRING_KEYS=example-flag-key
```

For staging flags validation, keep credentials in `.env` and use local-only
defines for non-default endpoints or sites:

```bash
flutter run \
  --dart-define FLAGS_ENDPOINT=https://preview.ff-cdn.datad0g.com/precompute-assignments \
  --dart-define FLAGS_EXPOSURE_ENDPOINT=https://browser-intake-datad0g.com/api/v2/exposures \
  --dart-define FLAGS_EVALUATION_ENDPOINT=https://browser-intake-datad0g.com/api/v2/flagevaluation
```
