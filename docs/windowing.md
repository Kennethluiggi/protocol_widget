# Windowing and Widget Mode

This page documents how Protocol Widget configures desktop windows and transitions between normal and widget modes.

## Normal Mode Behavior

In normal mode, the app is configured to support desktop editing and planning:

- Resizable window.
- Explicit minimum and maximum size constraints.
- Opaque background for standard desktop presentation.
- Custom title bar controls rendered in Flutter.

## Widget Mode Behavior

Widget mode is designed as a compact focus overlay:

- Compact bounded size profile.
- Frameless presentation.
- Transparent background.
- Shadow disabled.
- Non-resizable by OS frame (app provides its own resize handling).

## Transition Rules

### Entering widget mode

When entering widget mode, the app applies widget-specific configuration, including:

- Widget min/max constraints.
- Temporary resizable toggles to help Windows apply constraint transitions.
- Frameless mode.
- Shadow disabled.
- Transparent background.
- Resizable disabled.
- Widget target size applied and clamped.

### Exiting widget mode

When returning to normal mode, the app restores normal window behavior, including:

- Hidden title-bar style with Flutter-rendered custom controls.
- Shadow enabled.
- Opaque background restored.
- Previously saved full-mode size restored (clamped to normal bounds).
- Normal min/max constraints re-applied.
- Resizable re-enabled.

## Troubleshooting

### Can’t resize after leaving widget mode

Symptoms:

- Window appears in normal mode but drag-to-resize does not work.
- Size may be stuck near widget dimensions.

Diagnostics:

- Run with:

```bash
flutter run -d windows --dart-define=DEBUG_WINDOW=true
```

- Verify log sequence includes normal-bound restore steps and final resizable re-enable markers.

### Borders/shadows in widget mode

Symptoms:

- Widget mode still shows frame artifacts, border, or shadow.

Diagnostics:

- Run with:

```bash
flutter run -d windows --dart-define=DEBUG_WINDOW=true
```

- Confirm widget-mode logs show frameless call, shadow disable call, and transparent background path.

[Back to Docs Home](index.md)
