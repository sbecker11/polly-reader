#!/bin/zsh
# Start Polly from the frontmost app by copying the current selection (Cmd+C).
# Works in Cursor and other apps where macOS Services shortcuts do not fire.
# Best for Chrome / Claude web: bind globally via ./scripts/install-global-hotkeys.sh
# Requires one-time Accessibility permission for "System Events" (osascript prompt).

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
POLLY_HOME="${POLLY_HOME:-${SCRIPT_DIR:h}}"
READER_SCRIPT="${POLLY_HOME}/scripts/read-selection-with-polly.sh"

if [[ ! -x "${READER_SCRIPT}" ]]; then
  osascript -e 'display alert "read-selection-with-polly.sh not found" message "Re-run ./scripts/install-macos-quick-action.sh"'
  exit 1
fi

saved_clipboard="$(pbpaste)"
if ! osascript <<'APPLESCRIPT' 2>/dev/null; then
tell application "System Events" to keystroke "c" using command down
APPLESCRIPT
  osascript -e 'display alert "Accessibility permission needed" message "Open System Settings → Privacy & Security → Accessibility and allow the app running this script (Shortcuts, skhd, or Terminal) to control your computer."'
  exit 1
fi

sleep 0.15
TEXT="$(pbpaste)"
printf '%s' "${saved_clipboard}" | pbcopy

if [[ -z "${TEXT//[$'\t\r\n ']}" || "${TEXT}" == "${saved_clipboard}" ]]; then
  osascript -e 'display alert "No text selected" message "Select some text first, then press ⌃⌥P again."'
  exit 0
fi

printf '%s' "${TEXT}" | /bin/zsh -f "${READER_SCRIPT}"
