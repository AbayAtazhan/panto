# Architecture

Panto is one Swift package with a single executable target and no third-party dependencies.
Everything runs locally.

## Pipeline

```
ScreenCaptureKit ──► AVAssetWriter (HEVC .mov, native pixels)
        │                └── system audio ──► AAC 48 kHz stereo
        │                └── microphone   ──► AAC 48 kHz mono
        │
        ├──► clicks (CGEvent tap, or pointer-dwell fallback)
        └──► manual zooms (Carbon hotkey, floating HUD)
                     │
                     ▼
        ZoomShot timeline  ──► editor (add / drag / delete)
                     │
                     ▼
        AVMutableVideoComposition (per-frame affine camera)
        AVMutableAudioMix (system + mic)
                     │
                     ▼
        AVAssetExportSession ──► H.264 .mp4
```

The zoom is applied after recording, never live. That is why the camera can be smooth, stay
inside the frame, and be edited before export.

## Camera model

`Renderer.render` walks the video at 30 Hz and builds one CGAffineTransform per frame:

1. `ZoomMath.state(at:)` blends active shots with a smoothstep weight → target scale and point.
2. The point is clamped so the viewport `size / scale` never leaves the frame (no black bars).
3. The centre is low-pass filtered (`1 - exp(-dt / 0.10)`) to avoid jerky pans.
4. `translate(centre) · scale · translate(-centre)` is concatenated with the track's preferred
   transform.

Keyframes are only emitted when the matrix changes, which keeps the composition small.

## Audio

ScreenCaptureKit and `AVCaptureSession` both deliver `CMSampleBuffer`s timestamped with the host
clock. The writer session starts at the first video frame; audio buffers that arrive earlier are
dropped. Export re-inserts every audio track at its own time range, so sync survives.

## Permissions (TCC)

macOS keys Screen Recording to the code signature. Ad-hoc builds get a new cdhash on every
rebuild, which silently invalidates the grant. `make_app.sh` therefore:

- signs with the trusted `Panto Dev` certificate when `scripts/setup_signing.sh` has been run
  (designated requirement: `identifier + certificate leaf`), and
- otherwise resets the stale TCC entry when the cdhash changes, so at least the prompt reappears
  instead of a dead toggle.

## Distribution

- `scripts/make_app.sh` → `build/Panto.app` (icon, Info.plist, signature).
- `scripts/make_dmg.sh` → drag-to-Applications DMG, staged in a temp directory.
- `.github/workflows/release.yml` → on a `v*` tag, build and attach `Panto.dmg` + `Panto.zip`.
- `install.sh` → download, install to `/Applications`, strip quarantine.
- `Casks/panto.rb` → Homebrew cask with a caveat about notarization.

Notarization needs a Developer ID; the workflow already produces the artifacts, so it is a
two-line change once a certificate exists.
