#!/bin/bash
# Clears the stale Screen Recording / microphone grant for Panto.
# Run this after a rebuild if the toggle in System Settings looks enabled but
# the app still cannot capture. Then open Panto again and allow it.
set -euo pipefail
for service in ScreenCapture Microphone Accessibility; do
    tccutil reset "$service" app.panto.recorder >/dev/null 2>&1 || true
done
echo "Panto permissions reset. Open the app and allow screen recording, then quit and reopen it."
