# ScreenSketch

ScreenSketch is a lightweight macOS screen-annotation app. It creates transparent drawing surfaces across all connected displays while keeping its control window clickable.

## Features

- Pencil with color, width, and transparency controls
- Partial-stroke eraser with adjustable size
- Lasso selection with move, copy, cut, paste, and delete
- Independent drawings on every connected display
- Click-through Pointer mode
- Sidecar-compatible mouse-style input

## Shortcuts

- `Shift-Command-D`: show or hide ScreenSketch
- `Shift-Command-F`: clear all drawings
- `Shift-Command-Space`: undo the most recent drawing

## Build

Requires macOS 13 or later and Xcode 15 or later.

```sh
git clone <repository-url>
cd ScreenSketch
./scripts/build-app.sh
```

The standalone app is written to `dist/ScreenSketch.app`. It is ad-hoc signed for local use. You can also open `Package.swift` in Xcode and run the `ScreenSketch` scheme on My Mac.

Sidecar support depends on the events macOS exposes to the Mac. Pressure-sensitive Apple Pencil data is not currently handled.
