#!/bin/zsh
# macOS Quick Action helper: read selected text with polly-reader.
# Automator: Quick Action receives "text", Run Shell Script, pass input "as arguments", run:
#   /bin/zsh -f /Users/sbecker11/workspace-aws-polly/polly-reader/scripts/read-selection-with-polly.sh "$@"
#
# Standalone: echo "Hello." | ./scripts/read-selection-with-polly.sh

set -euo pipefail

if [[ -z "${HOME:-}" ]]; then
  export HOME="$(/usr/bin/id -un | xargs -I{} /bin/zsh -c 'echo ~{}')"
fi

SCRIPT_DIR="${0:A:h}"
POLLY_HOME="${POLLY_HOME:-${SCRIPT_DIR:h}}"
PYTHON="${POLLY_HOME}/venv/bin/python3"
READER="${POLLY_HOME}/polly-reader.py"
VOICES_CACHE="${TMPDIR:-/tmp}/polly-reader-voices.cache"
LAST_VOICE_FILE="${HOME}/.polly-reader-last-voice"
DEFAULT_VOICE_LINE="  9  Matthew"

if [[ ! -x "${PYTHON}" ]]; then
  osascript -e "display alert \"Python not found\" message \"Expected: ${PYTHON}\""
  exit 1
fi
if [[ ! -f "${READER}" ]]; then
  osascript -e "display alert \"polly-reader.py not found\" message \"Expected: ${READER}\""
  exit 1
fi

# Automator may pass selected text as arguments ("as arguments") or stdin ("to stdin").
TEXT=""
if (( $# > 0 )); then
  TEXT="$*"
elif ! [[ -t 0 ]]; then
  TEXT="$(cat)"
fi
if [[ -z "${TEXT//[$'\t\r\n ']}" ]]; then
  osascript -e 'display alert "No text received" message "Select some text first, then run the Quick Action again."'
  exit 0
fi

if [[ ! -f "${VOICES_CACHE}" || "${READER}" -nt "${VOICES_CACHE}" ]]; then
  "${PYTHON}" "${READER}" --list-voices > "${VOICES_CACHE}"
fi

typeset -a ITEMS ENGINES VOICES
current_engine=""

while IFS= read -r line; do
  if [[ "${line}" =~ '^\[engine: (.+)\]$' ]]; then
    current_engine="${match[1]}"
    ITEMS+=("${line}")
    ENGINES+=("")
    VOICES+=("")
  elif [[ "${line}" =~ '^[[:space:]]+[0-9]+[[:space:]]+(.+)$' ]]; then
    ITEMS+=("${line}")
    ENGINES+=("${current_engine}")
    VOICES+=("${match[1]}")
  fi
done < "${VOICES_CACHE}"

if (( ${#ITEMS} == 0 )); then
  osascript -e 'display alert "No voices found" message "Could not read --list-voices output."'
  exit 1
fi

ITEMS_FILE="$(mktemp "${TMPDIR:-/tmp}/polly-voices.XXXXXX")"
trap 'rm -f "${ITEMS_FILE}"' EXIT INT TERM
printf '%s\n' "${ITEMS[@]}" > "${ITEMS_FILE}"

if [[ ! -f "${LAST_VOICE_FILE}" ]]; then
  print -rn -- "${DEFAULT_VOICE_LINE}" > "${LAST_VOICE_FILE}"
fi

DEFAULT_PICK=""
DEFAULT_INDEX=0
if [[ -f "${LAST_VOICE_FILE}" ]]; then
  DEFAULT_PICK="${${(f)"$(<"${LAST_VOICE_FILE}")"}[1]}"
  for i in {1..${#ITEMS[@]}}; do
    if [[ "${ITEMS[$i]}" == "${DEFAULT_PICK}" ]]; then
      DEFAULT_INDEX=$i
      break
    fi
  done
fi

if (( DEFAULT_INDEX > 0 )); then
  PICK="$(osascript <<APPLESCRIPT
set itemsPath to POSIX file "${ITEMS_FILE}"
set voiceList to paragraphs of (read itemsPath)
set defaultItem to item ${DEFAULT_INDEX} of voiceList
set picked to choose from list voiceList with prompt "Choose Polly voice:" default items {defaultItem}
if picked is false then
  return ""
end if
return item 1 of picked
APPLESCRIPT
)"
else
  PICK="$(osascript <<APPLESCRIPT
set itemsPath to POSIX file "${ITEMS_FILE}"
set voiceList to paragraphs of (read itemsPath)
set picked to choose from list voiceList with prompt "Choose Polly voice:"
if picked is false then
  return ""
end if
return item 1 of picked
APPLESCRIPT
)"
fi

if [[ "${PICK}" == "false" || -z "${PICK}" ]]; then
  exit 0
fi

ENGINE=""
VOICE=""
for i in {1..${#ITEMS[@]}}; do
  if [[ "${ITEMS[$i]}" == "${PICK}" ]]; then
    ENGINE="${ENGINES[$i]}"
    VOICE="${VOICES[$i]}"
    break
  fi
done

if [[ -z "${ENGINE}" || -z "${VOICE}" ]]; then
  osascript -e 'display alert "Not a voice" message "Select a numbered voice (e.g. \"  9  Matthew\"), not an [engine: ...] heading."'
  exit 1
fi

print -rn -- "${PICK}" > "${LAST_VOICE_FILE}"

printf '%s' "${TEXT}" | "${PYTHON}" "${READER}" --stdin --engine "${ENGINE}" --voice-id "${VOICE}"
EXIT=$?
if [[ ${EXIT} -ne 0 ]]; then
  osascript -e "display alert \"polly-reader failed (exit ${EXIT})\" message \"Check Terminal or AWS credentials.\""
fi
exit ${EXIT}
