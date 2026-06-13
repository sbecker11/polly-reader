# macOS Quick Action: Read selected text with Polly

Right-click selected text in any app → **Services** → **Read selection with Polly**. No copy step; a voice picker appears, then Polly reads the selection aloud.

## Install (one command)

From the repo root:

```bash
./scripts/install-macos-quick-action.sh
```

This installs `~/Library/Services/Read selection with Polly.workflow`, which runs [`scripts/read-selection-with-polly.sh`](../scripts/read-selection-with-polly.sh).

Then:

1. **System Settings → Keyboard → Keyboard Shortcuts → Services**
2. Enable **Read selection with Polly** (look under **Text** or **General**)
3. Select text → **right-click** → **Services** → **Read selection with Polly**

If the menu item does not show up, quit and reopen the app, or run:

```bash
/System/Library/CoreServices/pbs -flush
```

## Prerequisites

- `polly-reader` working from the terminal (venv, AWS credentials)
- Smoke test:

  ```bash
  echo "Hello from Polly." | ./scripts/read-selection-with-polly.sh
  ```

## What happens

1. Selected text is passed on **stdin** (not the clipboard).
2. A single dialog lists all engines and indexed voices (same layout as `python polly-reader.py --list-voices`).
3. Pick a **numbered voice** row (not an `[engine: …]` heading).
4. Short text is synthesized directly (fast); audio plays via `afplay`.

The installer sets **Pass input: as arguments** (`"$@"` forwarded to the script) and disables Automator’s **Show when run** dialog, so you only see the voice picker. Your last chosen voice is remembered in `~/.polly-reader-last-voice` and pre-selected next time.

## Manual Automator setup (optional)

If you prefer not to use the installer:

1. Automator → **Quick Action** → receives **text** in **any application**
2. **Run Shell Script** → shell `/bin/zsh` → pass input **as arguments**
3. One line:

   ```zsh
   /bin/zsh -f /Users/sbecker11/workspace-aws-polly/polly-reader/scripts/read-selection-with-polly.sh "$@"
   ```

   Use `zsh -f` so Automator does not source `~/.zshenv` (which can break the action with spurious errors).

4. Save as **Read selection with Polly**

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| Not in right-click menu | Enable in **Keyboard Shortcuts → Services**; run `pbs -flush`; restart app |
| “No text received” | Re-run `./scripts/install-macos-quick-action.sh` (workflow must pass `"$@"`); select text before invoking |
| “Not a voice” | Choose a numbered voice, not an engine heading |
| Slow or errors | Run smoke test in Terminal; check AWS credentials |
| Text too long | Max **10,000** characters |

## Related CLI usage

```bash
python polly-reader.py --list-voices
python polly-reader.py --clipboard --engine neural --voice-id Joanna
```

See [README.md](../README.md) for all input modes.
