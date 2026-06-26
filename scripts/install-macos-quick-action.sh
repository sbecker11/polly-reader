#!/bin/zsh
# Install Start/Stop Polly Services to ~/Library/Services for right-click access.
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
POLLY_HOME="${POLLY_HOME:-${SCRIPT_DIR:h}}"
START_SCRIPT="${POLLY_HOME}/scripts/read-selection-with-polly.sh"
STOP_SCRIPT="${POLLY_HOME}/scripts/stop-reading-with-polly.sh"
SERVICES_DIR="${HOME}/Library/Services"
LEGACY_WORKFLOW="${SERVICES_DIR}/Read selection with Polly.workflow"

if [[ ! -x "${START_SCRIPT}" ]]; then
  echo "error: missing or non-executable: ${START_SCRIPT}" >&2
  exit 1
fi
if [[ ! -x "${STOP_SCRIPT}" ]]; then
  echo "error: missing or non-executable: ${STOP_SCRIPT}" >&2
  exit 1
fi

"${POLLY_HOME}/venv/bin/python3" - "${START_SCRIPT}" "${STOP_SCRIPT}" "${SERVICES_DIR}" <<'PY'
import plistlib
import shutil
import sys
import uuid
from pathlib import Path

start_script, stop_script, services_dir = sys.argv[1:4]
services_dir = Path(services_dir)
home = Path.home()
pbs_path = home / "Library/Preferences/pbs.plist"

START_MENU = "Start reading selection with Polly"
STOP_MENU = "Stop reading selection with Polly"
LEGACY_MENU = "Read selection with Polly"
START_KEY = f"(null) - {START_MENU} - runWorkflowAsService"
STOP_KEY = f"(null) - {STOP_MENU} - runWorkflowAsService"
LEGACY_KEY = f"(null) - {LEGACY_MENU} - runWorkflowAsService"
START_SHORTCUT = "~^p"  # Control-Option-P
STOP_SHORTCUT = "~^."  # Control-Option-period

WORKFLOWS = [
    {
        "filename": "Start reading selection with Polly.workflow",
        "menu_title": "Start reading selection with Polly",
        "script": start_script,
        "accepts_text": True,
    },
    {
        "filename": "Stop reading selection with Polly.workflow",
        "menu_title": "Stop reading selection with Polly",
        "script": stop_script,
        # NSSendTypes registers Stop under Text in System Settings (script ignores input).
        "accepts_text": True,
    },
]


def uid() -> str:
    return str(uuid.uuid4()).upper()


def shell_script_action(*, command_string: str, input_method: int) -> dict:
    input_uuid = uid()
    output_uuid = uid()
    action_uuid = uid()
    return {
        "action": {
            "AMAccepts": {
                "Container": "List",
                "Optional": True,
                "Types": ["com.apple.cocoa.string"],
            },
            "AMActionVersion": "2.0.3",
            "AMApplication": ["Automator"],
            "AMParameterProperties": {
                "COMMAND_STRING": {},
                "CheckedForUserDefaultShell": {},
                "inputMethod": {},
                "shell": {},
                "source": {},
            },
            "AMProvides": {
                "Container": "List",
                "Types": ["com.apple.cocoa.string"],
            },
            "ActionBundlePath": "/System/Library/Automator/Run Shell Script.action",
            "ActionName": "Run Shell Script",
            "ActionParameters": {
                "COMMAND_STRING": command_string,
                "CheckedForUserDefaultShell": False,
                "inputMethod": input_method,
                "shell": "/bin/zsh",
                "source": "",
            },
            "BundleIdentifier": "com.apple.RunShellScript",
            "CFBundleVersion": "2.0.3",
            "CanShowSelectedItemsWhenRun": False,
            "CanShowWhenRun": False,
            "Category": ["AMCategoryUtilities"],
            "Class Name": "RunShellScriptAction",
            "InputUUID": input_uuid,
            "Keywords": ["Shell", "Script", "Command", "Run", "Unix"],
            "OutputUUID": output_uuid,
            "ShowWhenRun": False,
            "UUID": action_uuid,
            "UnlocalizedApplications": ["Automator"],
            "arguments": {
                "0": {
                    "default value": input_method,
                    "name": "inputMethod",
                    "required": "0",
                    "type": "0",
                    "uuid": "0",
                },
                "1": {
                    "default value": "",
                    "name": "source",
                    "required": "0",
                    "type": "0",
                    "uuid": "1",
                },
                "2": {
                    "name": "COMMAND_STRING",
                    "required": "0",
                    "type": "0",
                    "uuid": "2",
                },
                "3": {
                    "default value": "/bin/zsh",
                    "name": "shell",
                    "required": "0",
                    "type": "0",
                    "uuid": "3",
                },
            },
            "isViewVisible": True,
            "location": "449.000000:368.000000",
            "nibPath": "/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib",
        },
        "isViewVisible": True,
    }


def install_workflow(spec: dict) -> Path:
    target = services_dir / spec["filename"]
    contents = target / "Contents"
    contents.mkdir(parents=True, exist_ok=True)

    service = {
        "NSMenuItem": {"default": spec["menu_title"]},
        "NSMessage": "runWorkflowAsService",
    }
    if spec["accepts_text"]:
        service["NSSendTypes"] = ["public.utf8-plain-text"]

    with (contents / "Info.plist").open("wb") as handle:
        plistlib.dump({"NSServices": [service]}, handle)

    if spec["accepts_text"]:
        command = f'/bin/zsh -f {spec["script"]} "$@"'
        input_method = 1
        input_type = "com.apple.Automator.text"
        use_automatic_input_type = 0
    else:
        command = f'/bin/zsh -f {spec["script"]}'
        input_method = 0
        input_type = "com.apple.Automator.nothing"
        use_automatic_input_type = 1

    workflow = {
        "AMApplicationBuild": "528",
        "AMApplicationVersion": "2.10",
        "AMDocumentVersion": "2",
        "actions": [shell_script_action(command_string=command, input_method=input_method)],
        "connectors": {},
        "workflowMetaData": {
            "applicationBundleIDsByPath": {},
            "applicationPaths": [],
            "inputTypeIdentifier": input_type,
            "outputTypeIdentifier": "com.apple.Automator.nothing",
            "presentationMode": 11,
            "processesInput": 0,
            "serviceInputTypeIdentifier": input_type,
            "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
            "serviceProcessesInput": 0,
            "systemImageName": "NSActionTemplate",
            "useAutomaticInputType": use_automatic_input_type,
            "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
        },
    }

    with (contents / "document.wflow").open("wb") as handle:
        plistlib.dump(workflow, handle)

    return target


def configure_service_shortcuts() -> None:
    if pbs_path.exists():
        with pbs_path.open("rb") as handle:
            pbs = plistlib.load(handle)
    else:
        pbs = {}

    status = dict(pbs.get("NSServicesStatus", {}))
    legacy = status.pop(LEGACY_KEY, {})
    start_shortcut = legacy.get("key_equivalent", START_SHORTCUT)

    presentation = {
        "enabled_context_menu": True,
        "enabled_services_menu": True,
        "presentation_modes": {
            "ContextMenu": True,
            "ServicesMenu": True,
            "TouchBar": True,
        },
    }

    status[START_KEY] = {
        **presentation,
        "key_equivalent": start_shortcut,
    }
    status[STOP_KEY] = {
        **presentation,
        "key_equivalent": STOP_SHORTCUT,
    }

    pbs["NSServicesStatus"] = status
    with pbs_path.open("wb") as handle:
        plistlib.dump(pbs, handle)

    print(f"Shortcuts: Start={start_shortcut!r} Stop={STOP_SHORTCUT!r} in {pbs_path}")


legacy = services_dir / "Read selection with Polly.workflow"
if legacy.exists():
    shutil.rmtree(legacy)
    print(f"Removed legacy service: {legacy}")

installed = []
for spec in WORKFLOWS:
    path = install_workflow(spec)
    installed.append(str(path))
    print(f"Installed: {path}")

configure_service_shortcuts()
print("\n".join(installed))
PY

/System/Library/CoreServices/pbs -flush 2>/dev/null || true

LAST_VOICE_FILE="${HOME}/.polly-reader-last-voice"
if [[ ! -f "${LAST_VOICE_FILE}" ]]; then
  print -rn -- "  9  Matthew" > "${LAST_VOICE_FILE}"
  echo "Created default last voice: ${LAST_VOICE_FILE}"
fi

echo ""
echo "Installed Start and Stop Services with default shortcuts:"
echo "  Start  ⌃⌥P  (Control-Option-P)"
echo "  Stop   ⌃⌥.  (Control-Option-period)"
echo ""
echo "Next steps:"
echo "  1. Open System Settings → Keyboard → Keyboard Shortcuts → Services"
echo "  2. Confirm both are enabled under Text:"
echo "       Start reading selection with Polly"
echo "       Stop reading selection with Polly"
echo "  3. Select text → ⌃⌥P to start; ⌃⌥. anytime to stop"
echo "     (Or use the right-click menu entries.)"
echo ""
echo "If shortcuts or menu items do not work, quit and reopen the app, or run:"
echo "  /System/Library/CoreServices/pbs -flush"
echo ""
echo "Using Cursor? Services shortcuts often fail there. Also run:"
echo "  ./scripts/install-cursor-hotkeys.sh"
