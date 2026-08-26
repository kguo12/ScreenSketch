# ScreenSketch

ScreenSketch is a lightweight macOS screen-annotation app. Quickly open and close to sketch quick math, drawings, write, or anything else you need to put pen to "paper" for.

It was designed by me because I needed a tool to help me sketch out ideas during research meetings with my collaborators, and I am a very particular human about these things.

## Features

- Pencil with color, width, and transparency controls
- Partial-stroke eraser with adjustable size
- Lasso selection with move, copy, cut, paste, and delete
- Independent drawings on every connected display
- Click-through Pointer mode
- Sidecar-compatible, works with Apple Pencil on iPad

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
