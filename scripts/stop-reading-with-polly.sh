#!/bin/zsh
# macOS Service helper: stop in-progress Polly playback or synthesis.
# Automator: Service receives text (ignored), Run Shell Script, pass input as arguments:
#   /bin/zsh -f /path/to/stop-reading-with-polly.sh "$@"

set -euo pipefail

stopped=0

if pgrep -x afplay >/dev/null 2>&1; then
  killall afplay 2>/dev/null && stopped=1
fi

if pkill -f "polly-reader.py" 2>/dev/null; then
  stopped=1
fi

if (( stopped )); then
  osascript -e 'display notification "Stopped Polly playback." with title "Polly Reader"' 2>/dev/null || true
fi

exit 0
