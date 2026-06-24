# Simple Example Agent Notes

This app is public example code. Keep it safe to publish and easy to run locally.

## Credentials

- Never commit real Datadog client tokens, application IDs, customer names, org names, or customer-owned flag keys.
- Runtime credentials must be passed to Flutter as `--dart-define` values.
- Keep `.env` ignored and local-only. It must not be committed.
- Prefer placeholder values in docs and tests, for example `pub...`, `fake-token`, or `fake-application-id`.

## Flags Example

- The default flags screen should use Datadog FFE dogfooding placeholders only.
- Custom/customer validation must be opt-in through `FLAGS_CUSTOM_*` `--dart-define` values.
- Do not hardcode customer-specific modes, labels, targeting attributes, or flag keys in Dart source.
- Do not add a fake local mode for flags. When credentials are provided, the example should exercise real Datadog Flags requests.
- Keep diagnostics compact. Timing, payload size, and event counters are useful, but should not dominate the example UI.

## Local Run Shape

Use local configuration like this:

```bash
set -a
source .env
set +a

flutter run \
  --dart-define DD_CLIENT_TOKEN="$DD_CLIENT_TOKEN" \
  --dart-define DD_APPLICATION_ID="$DD_APPLICATION_ID" \
  --dart-define DD_ENV="$DD_ENV" \
  --dart-define DD_SITE="$DD_SITE"
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
