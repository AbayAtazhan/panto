# Changelog

All notable changes to Panto. Format: [Keep a Changelog](https://keepachangelog.com),
versioning: [SemVer](https://semver.org).

## [Unreleased]

## [0.4.2] — 2026-10-30

### Fixed
- The floating recording bar now appears on the display being recorded, not on the main one.
- A hotkey press with the pointer on another display is ignored instead of zooming to a corner.

## [0.4.1] — 2026-10-30

### Added
- Real UI screenshot in the README, demo video (`docs/demo.mp4`).
- `Read me.txt` with first-launch steps inside the DMG.
- `CODE_OF_CONDUCT.md`, `.swift-format`, `make format` / `make lint`, Chinese README.

### Changed
- DMG copies are ad-hoc signed so Gatekeeper shows the standard “unidentified developer”
  prompt instead of a missing-signature error.
- Hotkey field uses a proportional font so ⌥⌘Z is readable.

## [0.4.0] — 2026-10-30

### Changed
- Redesigned the main window: material cards, icon rows, status pill, hover states.
- Version and release notes now live in the footer.

### Added
- Unit tests for the zoom timeline math (`Tests/PantoTests`, runs in CI).
- `CONTRIBUTING.md`, `SECURITY.md`, issue/PR templates, `Makefile`, architecture notes.
- CI now runs `swift test` before bundling.

## [0.3.1] — 2026-10-30

### Fixed
- Global hotkey beeped but never added a zoom: the Carbon handler was installed before the app
  had an event target. Installed lazily now, with status checks and a log.
- Duplicate `Panto.app` in Spotlight/Launchpad: `make_dmg.sh` left its staging copy behind.

### Added
- Live zoom counter in the floating recording bar.
- Diagnostics log at `~/Library/Logs/Panto.log`.

## [0.3.0] — 2026-10-30

### Added
- Microphone voiceover as a separate AAC track, mixed with system audio on export.
- DMG builds (`scripts/make_dmg.sh`), GitHub Releases workflow, one-line `install.sh`.
- `scripts/setup_signing.sh`: a trusted local code-signing identity so Screen Recording survives
  rebuilds.

## [0.2.0] — 2026-10-29

### Added
- Configurable global hotkey, floating REC bar with a Zoom button, menu bar “Zoom Now”.
- Manual zoom timeline: add, drag and delete zooms, preview, export.
- System audio capture.
- Native-resolution HEVC capture (no downscale), Rec.709 colour.

### Fixed
- Screen Recording permission lost after every rebuild (ad-hoc cdhash).

## [0.1.0] — 2026-10-29

### Added
- First public build: ScreenCaptureKit recording, click-driven auto-zoom, synthetic self-test.
