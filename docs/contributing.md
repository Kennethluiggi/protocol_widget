# Contributing

Thanks for improving Protocol Widget.

## Local Validation

Run the standard checks before opening a PR:

```bash
flutter analyze
flutter test
```

## Submitting Changes

1. Create a branch for your change.
2. Keep commits focused and descriptive.
3. Open a PR summarizing user impact, technical scope, and verification steps.

## Debug-first Workflow

When diagnosing issues, use a reproducible, flag-driven flow:

1. Reproduce with minimal steps.
2. Enable only the debug categories you need.
3. Capture logs from launch to failure.
4. Isolate domain:
   - Window behavior -> `DEBUG_WINDOW`
   - Lifecycle/resume -> `DEBUG_LIFECYCLE`
   - DB/persistence -> `DEBUG_DB`
   - Startup path -> `DEBUG_INIT`
   - Widget transitions -> `DEBUG_WIDGET_MODE`
5. Attach steps + logs to your PR/issue.

Useful command patterns:

```bash
flutter run -d windows --dart-define=DEBUG_WINDOW=true
flutter run -d windows --dart-define=DEBUG_LIFECYCLE=true
flutter run -d windows --dart-define=DEBUG_WINDOW=true --dart-define=DEBUG_LIFECYCLE=true
```

[Back to Docs Home](index.md)
