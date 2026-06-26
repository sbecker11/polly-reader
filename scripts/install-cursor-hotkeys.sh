#!/bin/zsh
# Bind ⌃⌥P / ⌃⌥. inside Cursor (Services shortcuts often fail in Electron apps).
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
POLLY_HOME="${POLLY_HOME:-${SCRIPT_DIR:h}}"
START_SCRIPT="${POLLY_HOME}/scripts/hotkey-start-polly.sh"
STOP_SCRIPT="${POLLY_HOME}/scripts/stop-reading-with-polly.sh"
CURSOR_USER="${HOME}/Library/Application Support/Cursor/User"
SETTINGS="${CURSOR_USER}/settings.json"
KEYBINDINGS="${CURSOR_USER}/keybindings.json"
TASKS="${CURSOR_USER}/tasks.json"

if [[ ! -x "${START_SCRIPT}" || ! -x "${STOP_SCRIPT}" ]]; then
  echo "error: run ./scripts/install-macos-quick-action.sh first" >&2
  exit 1
fi

mkdir -p "${CURSOR_USER}"

"${POLLY_HOME}/venv/bin/python3" - "${SETTINGS}" "${KEYBINDINGS}" "${TASKS}" "${START_SCRIPT}" "${STOP_SCRIPT}" <<'PY'
import json
import re
import sys
from pathlib import Path

settings_path, keybindings_path, tasks_path, start_script, stop_script = sys.argv[1:6]
start_script = str(start_script)
stop_script = str(stop_script)
settings_path = Path(settings_path)
keybindings_path = Path(keybindings_path)
tasks_path = Path(tasks_path)

POLLY_BINDINGS = [
    {
        "key": "ctrl+alt+p",
        "command": "workbench.action.tasks.runTask",
        "args": "Polly: Start reading selection",
        "when": "editorTextFocus",
    },
    {
        "key": "ctrl+alt+.",
        "command": "workbench.action.tasks.runTask",
        "args": "Polly: Stop reading selection",
    },
]

TASKS_DOC = {
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Polly: Start reading selection",
            "type": "shell",
            "command": start_script,
            "presentation": {
                "reveal": "never",
                "echo": False,
                "focus": False,
                "panel": "shared",
                "showReuseMessage": False,
            },
            "problemMatcher": [],
        },
        {
            "label": "Polly: Stop reading selection",
            "type": "shell",
            "command": stop_script,
            "presentation": {
                "reveal": "never",
                "echo": False,
                "focus": False,
                "panel": "shared",
                "showReuseMessage": False,
            },
            "problemMatcher": [],
        },
    ],
}


def load_jsonc(path: Path) -> dict | list:
    if not path.exists():
        return {} if path.name == "settings.json" else []
    text = path.read_text()
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"//.*?$", "", text, flags=re.M)
    text = re.sub(r",\s*([}\]])", r"\1", text)
    return json.loads(text or ("{}" if path.name == "settings.json" else "[]"))


def dump_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, indent=2) + "\n")


settings = load_jsonc(settings_path)
if not isinstance(settings, dict):
    settings = {}
settings["editor.accessibilitySupport"] = "on"
dump_json(settings_path, settings)
print(f"Updated {settings_path} (editor.accessibilitySupport=on)")

dump_json(tasks_path, TASKS_DOC)
print(f"Wrote {tasks_path}")

bindings = load_jsonc(keybindings_path)
if not isinstance(bindings, list):
    bindings = []

def binding_key(item: dict) -> tuple:
    return (item.get("key"), item.get("command"), item.get("args"))

existing = {binding_key(item) for item in bindings if isinstance(item, dict)}
for item in POLLY_BINDINGS:
    if binding_key(item) not in existing:
        bindings.append(item)

header = "// Place your key bindings in this file to override the defaults\n"
if keybindings_path.exists() and keybindings_path.read_text().startswith("//"):
    keybindings_path.write_text(header + json.dumps(bindings, indent=4) + "\n")
else:
    dump_json(keybindings_path, bindings)
print(f"Updated {keybindings_path}")
PY

echo ""
echo "Cursor hotkeys installed:"
echo "  ⌃⌥P  Start reading (in editor)"
echo "  ⌃⌥.  Stop reading"
echo ""
echo "Reload Cursor (Cmd+Shift+P → Developer: Reload Window) for keybindings to take effect."
echo "If ⌃⌥P still does nothing, grant Accessibility to Cursor when prompted by the first run."
