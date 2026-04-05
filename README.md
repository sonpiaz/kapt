<h1 align="center">Kapt</h1>

<p align="center">
  Lightweight macOS screenshot tool with annotation, OCR, and scrolling capture.
</p>

<p align="center">
  <a href="https://github.com/sonpiaz/kapt/blob/main/LICENSE"><img src="https://img.shields.io/github/license/sonpiaz/kapt" alt="License" /></a>
  <a href="https://github.com/sonpiaz/kapt/stargazers"><img src="https://img.shields.io/github/stars/sonpiaz/kapt" alt="Stars" /></a>
  <img src="https://img.shields.io/badge/macOS-15%2B-black" alt="macOS 15+" />
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6" />
</p>

---

## Features

- **Fullscreen capture** (`Cmd+Ctrl+3`) — Capture the active display
- **Region capture** (`Cmd+Ctrl+4`) — Select and capture a rectangular area
- **Scrolling capture** (`Cmd+Ctrl+5`) — Capture tall content with auto-scroll stitching
- **Annotation tools** — Arrow, rectangle, ellipse, line, freehand, text, counter, blur/pixelate, image insert
- **OCR** — Extract text from screenshots using the Vision framework
- **Smart thumbnails** — Floating preview after capture — click to annotate, drag to share
- **Customizable hotkeys** — Configure shortcuts in Settings
- **Menu bar app** — Always ready, no dock icon

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

## Requirements

- macOS 15.0 (Sequoia) or later
- Screen Recording permission (requested on first launch)
- Accessibility permission (for scrolling capture auto-scroll)

## Development

```bash
./scripts/dev.sh    # Kill → rebuild → relaunch (~3 seconds)
```

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
```

## Tech Stack

| Technology | Purpose |
|-----------|---------|
| [Swift 6](https://swift.org/) | Language |
| SwiftUI | UI framework |
| ScreenCaptureKit | Screen capture API |
| Swift Package Manager | Build system |
| [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) | Hotkey management |

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Related

- [Yap](https://github.com/sonpiaz/yap) — Push-to-talk dictation for macOS
- [Pheme](https://github.com/sonpiaz/pheme) — AI meeting notes with real-time transcript & auto-summary
- [hidrix-tools](https://github.com/sonpiaz/hidrix-tools) — MCP server for web & social search
- [affiliate-skills](https://github.com/Affitor/affiliate-skills) — 45 AI agent skills
- [content-pipeline](https://github.com/Affitor/content-pipeline) — AI-powered LinkedIn content generation

## License

MIT — see [LICENSE](LICENSE) for details.

---

<p align="center">Built by <a href="https://github.com/sonpiaz">Son Piaz</a></p>
