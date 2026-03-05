# Debug Logging

Protocol Widget uses a gated debug logging utility in `lib/debug/debug_log.dart`.

- Logs are emitted only when both conditions are true:
  - Flutter is running in debug mode (`kDebugMode`).
  - The corresponding `--dart-define` flag is enabled.
- In normal builds (without enabled flags), no category output is produced.

## Log Categories

- `DEBUG_WINDOW`
  - Window initialization, mode transitions, sizing/clamping, bounds restoration.
- `DEBUG_LIFECYCLE`
  - App lifecycle events (for example, resume handling and state recovery flow).
- `DEBUG_INIT`
  - Startup and initialization path diagnostics.
- `DEBUG_DB`
  - Isar-related runtime diagnostics.
- `DEBUG_WIDGET_MODE`
  - Widget mode specific state transition checkpoints.

## Exact Run Commands

```bash
flutter run -d windows --dart-define=DEBUG_WINDOW=true
flutter run -d windows --dart-define=DEBUG_LIFECYCLE=true
flutter run -d windows --dart-define=DEBUG_WINDOW=true --dart-define=DEBUG_LIFECYCLE=true
```

Additional useful flags follow the same pattern:

```bash
flutter run -d windows --dart-define=DEBUG_INIT=true
flutter run -d windows --dart-define=DEBUG_DB=true
flutter run -d windows --dart-define=DEBUG_WIDGET_MODE=true
```

## Where Window Logs Come From

Conceptually, `DEBUG_WINDOW` logs come from:

- Initial window readiness/setup.
- Entering widget mode (bounds, frameless/shadow/background changes, target size).
- Exiting widget mode (restore size, normal bounds reapplication, resizable reset).
- Normal-mode sizing clamped to display/window constraints.

## What Good Logs Look Like

Good logs are:

- **Scoped** to one repro flow (startup, mode toggle, resize, resume).
- **Sequential** (clear before/after state transitions).
- **Flag-limited** so noise is controlled (for example `DEBUG_WINDOW` + `DEBUG_WIDGET_MODE`).
- **Annotated** by the tester with expected vs actual behavior.

## Capturing Logs for Bug Reports

1. Reproduce the issue with the smallest possible sequence.
2. Enable the minimum useful flags (start with `DEBUG_WINDOW` for window bugs).
3. Run from terminal so stdout/stderr is captured.
4. Copy logs from app start through failure.
5. Include:
   - OS version and Flutter version.
   - Window mode before/after action.
   - Expected behavior and actual behavior.

[Back to Docs Home](index.md)
