# Kapt

Lightweight macOS screenshot tool with annotation, OCR, and scrolling capture.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-black.svg)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-orange.svg)](https://swift.org/)

Kapt lives in your menu bar, ready to capture screenshots with powerful annotation tools, optical character recognition, and scrolling capture for tall content. Customizable hotkeys, native drag-to-share, and zero dependencies beyond macOS.

## Install

### Homebrew (recommended)

```bash
brew install --cask sonpiaz/tap/kapt
```

### Build from source

```bash
git clone https://github.com/sonpiaz/kapt.git
cd kapt
./scripts/install.sh
```

## Features

### Capture Modes

| Mode | Hotkey | Description |
|------|--------|-------------|
| Fullscreen | `Cmd+Ctrl+3` | Capture the active display |
| Region | `Cmd+Ctrl+4` | Select and capture a rectangular area |
| Scrolling | `Cmd+Ctrl+5` | Capture tall content with auto-scroll stitching |

### Annotation Tools

Arrow, rectangle, ellipse, line, freehand draw, text, counter numbers, blur/pixelate regions, image insertion — with full undo/redo.

### OCR

Extract text from captured images using the Vision framework. View and copy recognized text instantly.

### Smart Thumbnails

Floating preview after capture — click to annotate, drag to any app to share. Auto-dismisses after 5 seconds.

## Screenshots

<!-- Add screenshots here -->

## Requirements

- macOS 15.0 (Sequoia) or later
- Screen Recording permission (requested on first launch)
- Accessibility permission (for scrolling capture auto-scroll)

## Development

```bash
# Quick dev cycle (~3 seconds)
./scripts/dev.sh
```

This kills any running instance, rebuilds, updates the app bundle, and relaunches.

## Project Structure

```
Sources/
├── KaptApp.swift                — App entry, menu bar popover
├── AppState.swift               — Capture orchestration
├── Capture/                     — ScreenCaptureKit, region selection, scrolling
├── Annotation/                  — Canvas, shapes, toolbar
├── OCR/                         — Vision framework text recognition
├── Hotkeys/                     — Keyboard shortcut registration
├── MenuBar/                     — Preferences UI
└── Overlay/                     — Floating thumbnail, drag support

scripts/
├── install.sh                   — Build + create .app bundle
└── dev.sh                       — Quick dev cycle
```

## Tech Stack

- **Language:** Swift 6
- **UI:** SwiftUI
- **Capture:** ScreenCaptureKit
- **Build:** Swift Package Manager
- **Dependency:** [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) (Sindre Sorhus)

## Contributing

Pull requests welcome. For major changes, please open an issue first.

1. Fork the repo
2. Create your branch (`git checkout -b feat/amazing-feature`)
3. Commit (`git commit -m 'feat: add amazing feature'`)
4. Push (`git push origin feat/amazing-feature`)
5. Open a Pull Request

## License

[MIT](LICENSE) — Son Piaz
