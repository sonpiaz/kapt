# Kapt

Lightweight macOS screenshot tool with annotation, OCR, and scrolling capture.

Kapt is a menu bar app that captures screenshots with powerful annotation tools, optical character recognition, and support for tall scrolling content. It integrates seamlessly into your workflow with customizable hotkeys and native drag-to-share.

## Requirements

- macOS 15.0 (Sequoia) or later
- Screen Recording permission (requested on first launch)
- Accessibility permission (required for auto-scroll in scrolling capture)

## Install

Clone the repository and run the install script:

```bash
git clone https://github.com/sonpiaz/kapt.git
cd kapt
./scripts/install.sh
```

This builds a release binary and creates a .app bundle at `~/Applications/Kapt.app`. The app will launch immediately. Search for "Kapt" in Spotlight to launch it anytime.

## Development

For rapid iteration during development:

```bash
./scripts/dev.sh
```

This script kills any running instance, rebuilds the release binary, updates the app bundle, and relaunches it. Typical cycle: ~3 seconds.

## Features

**Capture Modes**
- **Fullscreen** (default: Cmd+Ctrl+3) — Capture the active display
- **Region** (default: Cmd+Ctrl+4) — Select and capture a rectangular area
- **Scrolling** (default: Cmd+Ctrl+5) — Capture tall content with auto-scroll and manual frame stitching

**Annotation Tools**
- Arrow, rectangle, ellipse, line, freehand draw
- Text with custom sizing and positioning
- Counter numbers for sequential annotations
- Blur and pixelate regions
- Image insertion
- Undo/redo support

**OCR & Recognition**
- Extract text from captured images using Vision framework
- View and copy recognized text

**Smart Thumbnails**
- Floating preview appears in bottom-right corner after capture (auto-dismisses after 5 seconds)
- Click thumbnail to annotate
- Drag thumbnail to any app to share (native NSDraggingSource)

**Preferences**
- Configurable hotkeys (Settings → Hotkeys)
- Auto-copy to clipboard (default: on)
- Capture sound toggle
- Save location selection
- Scrolling speed and max height configuration
- Multi-display support (choose active or specific display)

**System Integration**
- Menu bar app (no dock icon)
- Launch at Login via SMAppService
- Native macOS permissions handling
- High-resolution display support

## Project Structure

```
Sources/
  KaptApp.swift              — App entry, menu bar popover, AppDelegate
  AppState.swift             — Capture orchestration, state management
  Capture/
    CaptureEngine.swift      — ScreenCaptureKit integration
    RegionSelectionWindow    — Region selection UI and interaction
    ScrollingCaptureController — Scrolling capture state machine
    FrameStitcher.swift      — Frame alignment and stitching for scrolling
    ScrollingCaptureHUD.swift — HUD overlay during scrolling capture
  Annotation/
    AnnotationState.swift    — Annotation drawing state
    AnnotationCanvas.swift   — Canvas rendering and hit detection
    AnnotationEditorView.swift — Main editor UI
    Toolbar/
      AnnotationToolbar.swift — Tool selection and color picker
    Shapes/                  — Arrow, rect, ellipse, line, text, blur, etc.
    Tools/                   — Tool definitions and configuration
  Hotkeys/
    HotkeyRegistration.swift — Keyboard shortcut registration
    HotkeyNames.swift        — Hotkey definitions (Cmd+Ctrl+3/4/5)
  MenuBar/
    PreferencesView.swift    — Settings UI (General, Scrolling, Hotkeys tabs)
  OCR/
    OCREngine.swift          — Vision framework text recognition
    OCRResultView.swift      — OCR results display
  Overlay/
    ThumbnailPreview.swift   — Floating thumbnail with drag support
    FloatingPanel.swift      — Generic floating window helper
  Utilities/
    CGImage+Extensions.swift — Image utilities and clipboard integration
    Permissions.swift        — System permission handling

scripts/
  install.sh                 — Build release and create .app bundle
  dev.sh                     — Quick dev cycle: kill → build → update → relaunch
  generate_icon.py           — Generate app icon from template
```

## Build Details

- **Language:** Swift 6
- **UI Framework:** SwiftUI
- **Capture API:** ScreenCaptureKit
- **Dependencies:** KeyboardShortcuts (Sindre Sorhus)
- **Target Platform:** macOS 15+
- **Build System:** Swift Package Manager

The release binary is compiled with `-c release` optimization and packaged as a macOS .app bundle with a generated Info.plist. The bundle includes LSUIElement set to true, which hides the dock icon and makes Kapt a true menu bar app.

## Permissions

Kapt requests two key permissions:

1. **Screen Recording** — Required to capture the screen via ScreenCaptureKit
2. **Accessibility** — Required for auto-scrolling during scrolling capture mode

Both are requested at runtime when first needed. Grant them in System Settings → Privacy & Security.

## Notes

- Captured images are saved to the location specified in Preferences (default: Desktop)
- Hotkeys are fully customizable in Preferences
- The app persists state in UserDefaults for configuration and last save location
- Screenshots can be dragged directly from the thumbnail to any app

---

Private project. All rights reserved.
