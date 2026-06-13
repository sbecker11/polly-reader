#!/bin/zsh
# Install "Read selection with Polly" to ~/Library/Services for right-click access.
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
POLLY_HOME="${POLLY_HOME:-${SCRIPT_DIR:h}}"
READER_SCRIPT="${POLLY_HOME}/scripts/read-selection-with-polly.sh"
WORKFLOW_NAME="Read selection with Polly.workflow"
TARGET="${HOME}/Library/Services/${WORKFLOW_NAME}"

if [[ ! -x "${READER_SCRIPT}" ]]; then
  echo "error: missing or non-executable: ${READER_SCRIPT}" >&2
  exit 1
fi

mkdir -p "${TARGET}/Contents"

cat > "${TARGET}/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSBackgroundColorName</key>
			<string>background</string>
			<key>NSIconName</key>
			<string>NSActionTemplate</string>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>Read selection with Polly</string>
			</dict>
			<key>NSMessage</key>
			<string>runWorkflowAsService</string>
			<key>NSSendTypes</key>
			<array>
				<string>public.utf8-plain-text</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
EOF

"${POLLY_HOME}/venv/bin/python3" - "${READER_SCRIPT}" "${TARGET}/Contents/document.wflow" <<'PY'
import plistlib
import sys
import uuid
from pathlib import Path

script_path = sys.argv[1]
output_path = Path(sys.argv[2])
# zsh -f skips ~/.zshenv and ~/.zshrc (Automator treats their output as errors).
# Pass "$@" so selected text reaches the script when inputMethod is "as arguments".
command_string = f'/bin/zsh -f {script_path} "$@"'

def uid() -> str:
    return str(uuid.uuid4()).upper()

input_uuid = uid()
output_uuid = uid()
action_uuid = uid()

workflow = {
    "AMApplicationBuild": "528",
    "AMApplicationVersion": "2.10",
    "AMDocumentVersion": "2",
    "actions": [
        {
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
                    "inputMethod": 1,
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
                        "default value": 1,
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
    ],
    "connectors": {},
    "workflowMetaData": {
        "applicationBundleIDsByPath": {},
        "applicationPaths": [],
        "inputTypeIdentifier": "com.apple.Automator.text",
        "outputTypeIdentifier": "com.apple.Automator.nothing",
        "presentationMode": 11,
        "processesInput": 0,
        "serviceInputTypeIdentifier": "com.apple.Automator.text",
        "serviceOutputTypeIdentifier": "com.apple.Automator.nothing",
        "serviceProcessesInput": 0,
        "systemImageName": "NSActionTemplate",
        "useAutomaticInputType": 0,
        "workflowTypeIdentifier": "com.apple.Automator.servicesMenu",
    },
}

with output_path.open("wb") as handle:
    plistlib.dump(workflow, handle)
PY

LAST_VOICE_FILE="${HOME}/.polly-reader-last-voice"
if [[ ! -f "${LAST_VOICE_FILE}" ]]; then
  print -rn -- "  9  Matthew" > "${LAST_VOICE_FILE}"
  echo "Created default last voice: ${LAST_VOICE_FILE}"
fi

echo "Installed: ${TARGET}"
echo ""
echo "Next steps:"
echo "  1. Open System Settings → Keyboard → Keyboard Shortcuts → Services"
echo "  2. Enable \"Read selection with Polly\" (under Text or General)"
echo "  3. Select text, right-click → Services → Read selection with Polly"
echo ""
echo "If it does not appear immediately, quit and reopen the app, or run:"
echo "  /System/Library/CoreServices/pbs -flush"
