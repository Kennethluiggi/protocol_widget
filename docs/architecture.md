# Architecture

Protocol Widget is organized around a small set of desktop-focused layers.

## High-Level Overview

### 1) UI Layer (`protocol_screen`)

The primary screen is `ProtocolScreen`, which owns:

- Task list rendering and control interactions.
- Timer/session display updates.
- Custom title bar UI in normal mode.
- Widget-mode specific compact UI and resizing affordances.

### 2) Window Management Layer

Window behavior is orchestrated from startup and screen-level helpers:

- App startup performs desktop window readiness and base hidden-title-bar setup.
- `ProtocolScreen` applies mode-specific window state through dedicated functions.
- Normal mode and widget mode each have distinct sizing constraints.

### 3) Data Layer (`IsarDb`)

Persistence is local and Isar-backed:

- `IsarDb.instance()` opens a singleton database in application support directory.
- Tasks and settings are persisted via the same collection model.
- Resume/lifecycle flow can reset/reopen Isar to recover cleanly.

## Where to Edit

### Widget mode behavior

Key functions to review/edit:

- `_setWidgetMode(bool value)`
- `_applyWidgetModeWindowState(bool enabled)`
- `_resizeWidgetByDelta(Offset delta)`

These cover state transitions, persistence of mode selection, and widget-size manipulation.

### Normal mode sizing/resizing

Key sizing responsibilities:

- `_normalWindowBounds()` defines normal min/max constraints.
- `_applyNormalWindowSizingForTasks(int taskCount)` applies task-driven height sizing.
- `_applyNormalBoundsOnlyOnce()` clamps/initializes normal bounds on startup path.

### Title bar controls

Custom title bar interactions are provided by `_buildCustomTitleBar()` and call `window_manager` methods for:

- Dragging (`startDragging`)
- Minimize
- Maximize/unmaximize
- Close
- User toggles (always-on-top and widget mode)

## Desktop-first Design Decisions

- Prioritizes desktop window semantics over mobile navigation patterns.
- Uses custom Flutter title bar and control row for consistent behavior.
- Keeps widget mode intentionally compact and distraction-light.
- Treats local persistence as first-class for reliability and offline usage.

[Back to Docs Home](index.md)
