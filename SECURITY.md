# Security policy

## Reporting a vulnerability

Open a private security advisory on GitHub, or email `security@example.com`
(replace with a real address before publishing). Please do not open a public issue for
anything that could be exploited.

You can expect an answer within 7 days. Fixes ship in the next patch release, and credit is
given in `CHANGELOG.md` unless you prefer to stay anonymous.

## What Panto can access

Panto is a screen recorder, so it asks for powerful permissions. Here is exactly what it does
with them:

| Permission | Why | Where it goes |
|---|---|---|
| Screen Recording (+ system audio) | The whole point: capture a display | Written to a local `.mov` in `~/Movies/Panto` |
| Microphone | Optional voiceover track | Same local `.mov`, second audio track |
| Accessibility | Optional: detect clicks for auto-zoom | Click coordinates only, kept in memory for the render |

## What Panto does not do

- No network requests. No analytics, no crash reporting, no accounts.
- No cloud, no upload, no “share link”.
- No passwords, no keychain items, no biometric templates.
- The diagnostics log (`~/Library/Logs/Panto.log`) is local and contains no screen content —
  only timestamps, permission and hotkey state.

## Known limitations

- Release builds are ad-hoc signed (or signed with a local `Panto Dev` certificate) until the
  project has a Developer ID. Verify the source before running builds from strangers.
- Screen recording is inherently sensitive: anything visible on the captured display ends up in
  the file. Panto does not redact anything automatically.

## Supported versions

Only the latest release receives security fixes.
