# Contributing to Panto

Thanks for wanting to help. Panto is small on purpose: one Swift package, no third-party
dependencies, no Electron.

## Requirements

- macOS 15 or newer
- Xcode Command Line Tools — enough to build and run:

  ```sh
  xcode-select --install
  ```

- Full Xcode — only if you want to run `swift test` (XCTest ships with Xcode, not with the
  Command Line Tools).

## Build and run

```sh
make app          # build Panto.app (ad-hoc or Panto Dev signature)
make run          # build and open it
make selftest     # synthetic recording → zoom → PNG frames, no permissions needed
```

`make selftest` is the fastest feedback loop for the camera math. It renders a fake landing
page, applies the zoom plan, and writes frames to a temp directory so you can look at them.

## Where things live

| Path | What |
|---|---|
| `Sources/Panto/Recorder.swift` | ScreenCaptureKit capture, AVAssetWriter, audio tracks |
| `Sources/Panto/ZoomMath.swift` | Shot timeline, weights, transform math (pure, testable) |
| `Sources/Panto/Renderer.swift` | Camera model + AVVideoComposition export |
| `Sources/Panto/EditorView.swift` | Timeline editor UI |
| `Sources/Panto/HotKey.swift` | Carbon global hotkey + hotkey recorder field |
| `Sources/Panto/UI` (ContentView, HUD) | SwiftUI surfaces |
| `Tests/PantoTests` | Zoom math unit tests (`swift test`, needs Xcode) |

## Pull requests

- One thing per PR. If it touches recording and UI, split it.
- Keep the Swift language mode at 5 and keep the package dependency-free.
- Run `make selftest` and `swift build -c release` before pushing.
- Add a line to `CHANGELOG.md` under “Unreleased”.
- Screenshots or a short clip for anything visual.
- CI must be green (`build.yml`).

## Commit style

Imperative subject under ~70 characters, then a body explaining the why:

```
Fix hotkey that beeped but never zoomed

The handler was installed before NSApplication had an event target…
```

## Good first issues

- Cursor smoothing presets
- Per-shot zoom strength
- Microphone gain / ducking
- README translations (`README.zh-CN.md`, `README.ru.md`)
- `swift-format` config + CI check

## Code of conduct

Be decent. Harassment, gatekeeping and “just read the docs” answers are not welcome.
