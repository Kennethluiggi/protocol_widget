# Protocol Widget

Protocol Widget is a Flutter desktop-first productivity app focused on running a daily protocol of tasks with lightweight timing controls, fast status changes, and local persistence. It is optimized for Windows today, with a compact widget mode for always-visible focus and a full desktop mode for planning and control.

## Key Features

- **Desktop-first workflow** with custom window chrome and direct window controls.
- **Widget mode** for a compact, always-on-top, frameless focus surface.
- **Task execution controls** for running, pausing, resuming, and completing protocol items.
- **Local-first data model** backed by Isar for offline persistence.
- **Debug-gated diagnostics** for windowing, lifecycle, init, DB, and widget mode behavior.

## Quick Start (Windows)

### Prerequisites

- Flutter SDK installed and on your PATH.
- Windows desktop toolchain enabled for Flutter.
- A compatible C++ build environment for Flutter desktop.

### Run

```bash
flutter pub get
flutter run -d windows
```

### Analyze and test

```bash
flutter analyze
flutter test
```

## Docs

- [Documentation Home](docs/index.md)
- [Architecture Overview](docs/architecture.md)
- [Windowing and Widget Mode](docs/windowing.md)
- [Task Engine and Persistence](docs/tasks.md)
- [Debug Logging Guide](docs/debugging.md)
- [Contributing](docs/contributing.md)

## Debug Logging

Debug logging is controlled through `--dart-define` flags and only emits in debug builds when enabled. See [docs/debugging.md](docs/debugging.md) for category details and exact run commands.

## Architecture

For a high-level system map (UI, windowing, and Isar data layers), start at [docs/architecture.md](docs/architecture.md).
