# Simple Example Agent Notes

This app is public example code. Keep it safe to publish and easy to run locally.

## Credentials

- Never commit real Datadog client tokens, application IDs, customer names, org names, or customer-owned flag keys.
- Runtime credentials and optional flag overrides should come from the generated
  local `.env` file.
- Keep `.env` ignored and local-only. It must not be committed.
- Prefer placeholder values in docs and tests, for example `pub...`, `fake-token`, or `fake-application-id`.

## Flags Example

- The default flags screen should use Datadog FFE dogfooding placeholders only.
- Custom/customer validation belongs in an FFE-owned dogfooding app outside
  this repository, not in this public example app.
- Do not hardcode customer-specific modes, labels, targeting attributes, or flag keys in Dart source.
- Do not add a fake local mode for flags. When credentials are provided, the example should exercise real Datadog Flags requests.
- Keep this app focused on basic initialization and typed evaluation. Timing,
  payload size, and event counters belong in the FFE-owned dogfooding app.

## Local Run Shape

Generate local configuration before running the app:

```bash
../../generate_env.sh
flutter run
```

Use the FFE-owned dogfooding app outside this repository for private custom
validation.

For staging flags validation, keep credentials, site, and optional `FLAGS_*`
overrides in `.env`:

```bash
DD_SITE=datad0g.com
FLAGS_TARGETING_KEY=test_subject4
```
