#!/bin/zsh
# Global hotkeys for Chrome, Claude web, and other apps where macOS Services
# do not receive the selection (or Services shortcuts do not fire).
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
POLLY_HOME="${POLLY_HOME:-${SCRIPT_DIR:h}}"
START_SCRIPT="${POLLY_HOME}/scripts/hotkey-start-polly.sh"
STOP_SCRIPT="${POLLY_HOME}/scripts/stop-reading-with-polly.sh"
SKHDRC="${HOME}/.config/skhd/skhdrc"

if [[ ! -x "${START_SCRIPT}" || ! -x "${STOP_SCRIPT}" ]]; then
  echo "error: run ./scripts/install-macos-quick-action.sh first" >&2
  exit 1
fi

if command -v skhd >/dev/null 2>&1; then
  mkdir -p "$(dirname "${SKHDRC}")"
  if ! grep -q "polly-reader global hotkeys" "${SKHDRC}" 2>/dev/null; then
    cat >> "${SKHDRC}" <<EOF

# polly-reader global hotkeys (Chrome, Claude web, etc.)
ctrl + alt - p : /bin/zsh -f ${START_SCRIPT}
ctrl + alt - period : /bin/zsh -f ${STOP_SCRIPT}
EOF
    echo "Added bindings to ${SKHDRC}"
  else
    echo "skhd bindings already present in ${SKHDRC}"
  fi
  if command -v brew >/dev/null 2>&1; then
    brew services restart skhd 2>/dev/null || skhd --reload 2>/dev/null || echo "Restart skhd manually: skhd --reload"
  else
    echo "Restart skhd manually: skhd --reload"
  fi
  echo ""
  echo "skhd installed: ⌃⌥P start, ⌃⌥. stop (global, all apps including Chrome)"
  echo "Grant Accessibility to skhd in System Settings if prompted."
  exit 0
fi

cat <<EOF
No skhd found — set up a global hotkey for Chrome / Claude web:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OPTION A — Shortcuts app (macOS Monterey+)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Open **Shortcuts** from Applications (Spotlight: type "Shortcuts").
   (This is NOT Automator.)

2. Click **+** (top-right toolbar) or **File → New Shortcut**.

3. On the RIGHT side of the window, use the search box and type:
      shell
   (or: Run Shell Script)

4. Under **Scripting**, double-click **Run Shell Script**
   (it appears in the workflow on the left).

5. In the Run Shell Script action:
   - Shell: /bin/zsh
   - Input: None  (or "no input")
   - Script box, one line:
     /bin/zsh -f ${START_SCRIPT}

6. Rename the shortcut (top of window): Polly Start

7. Open shortcut details:
   - Click the ⓘ (info) icon in the toolbar, OR
   - Right-click the shortcut in the list → **Shortcut Details**
   - Click **Add Keyboard Shortcut** → press ⌃⌥P

8. Repeat for **Polly Stop** with:
     /bin/zsh -f ${STOP_SCRIPT}
   Keyboard shortcut: ⌃⌥.

9. System Settings → Privacy & Security → Accessibility → enable **Shortcuts**

If ⌃⌥P is already used by Services, remove it under
System Settings → Keyboard → Shortcuts → Services → Text,
or pick e.g. ⌃⌥⇧P for the Shortcuts action.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OPTION B — skhd (global hotkey, no Shortcuts UI)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  brew install skhd
  brew services start skhd
  ./scripts/install-global-hotkeys.sh

Grant Accessibility to skhd when prompted.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Test (Chrome focused, text selected in Claude)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ${START_SCRIPT}

EOF
