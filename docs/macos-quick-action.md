# macOS Quick Action: Read selected text with Polly

Select text in any app, then run **Start reading selection with Polly** from the right-click menu or a keyboard shortcut. Use **Stop reading selection with Polly** to cancel playback or in-progress synthesis.

## Install (one command)

From the repo root:

```bash
./scripts/install-macos-quick-action.sh
```

This installs two Services in `~/Library/Services/`:

| Service | Script |
|---------|--------|
| **Start reading selection with Polly** | [`read-selection-with-polly.sh`](../scripts/read-selection-with-polly.sh) |
| **Stop reading selection with Polly** | [`stop-reading-with-polly.sh`](../scripts/stop-reading-with-polly.sh) |

The installer removes the legacy **Read selection with Polly** service if present.

Then:

1. **System Settings → Keyboard → Keyboard Shortcuts → Services**
2. Enable both services under **Text**:
   - **Start reading selection with Polly**
   - **Stop reading selection with Polly**

   (Stop is registered as a text service so it appears in this list; it ignores the selection and works via **⌃⌥.** even without one.)
3. Select text → **right-click** → **Start reading selection with Polly**

If the menu items do not show up, quit and reopen the app, or run:

```bash
/System/Library/CoreServices/pbs -flush
```

## Prerequisites

- `polly-reader` working from the terminal (venv, AWS credentials)
- Smoke test:

  ```bash
  echo "Hello from Polly." | ./scripts/read-selection-with-polly.sh
  ./scripts/stop-reading-with-polly.sh
  ```

## Keyboard shortcuts

### Chrome, Claude web, and other browsers (recommended)

macOS **Services** often **do not receive text** selected inside web pages (Claude in Chrome, many React apps). The Services menu and **⌃⌥P** under System Settings → Services may do nothing even when Copy works.

Use a **global copy-based hotkey** instead:

```bash
./scripts/install-global-hotkeys.sh
```

This either configures **skhd** (if installed) or prints steps to bind **`hotkey-start-polly.sh`** in the **Shortcuts** app. That script simulates **Cmd+C**, then reads the clipboard — same text you copied manually.

| Action | Shortcut (default) |
|--------|-------------------|
| Start | **⌃⌥P** |
| Stop | **⌃⌥.** |

Grant **Accessibility** to **Shortcuts** (or **skhd**) on first use. If **⌃⌥P** conflicts with the Services binding, remove the Services shortcut under **Text** or pick e.g. **⌃⌥⇧P** for the Shortcuts action.

Quick test with Chrome focused and text selected:

```bash
./scripts/hotkey-start-polly.sh
```

### In Cursor editor

macOS **Services** shortcuts (System Settings → Services) usually **do not work in Cursor** even when configured. Install Cursor-native bindings instead:

```bash
./scripts/install-cursor-hotkeys.sh
```

Then **reload Cursor** (Cmd+Shift+P → **Developer: Reload Window**). With text selected in the editor:

| Action | Shortcut |
|--------|----------|
| Start | **⌃⌥P** |
| Stop | **⌃⌥.** |

Start copies the selection (Cmd+C) and reads it — grant **Accessibility** to Cursor when macOS prompts on first use.

### macOS Services shortcuts (TextEdit, some native apps)

The installer pre-assigns defaults in `~/Library/Preferences/pbs.plist`:

| Service | Shortcut |
|---------|----------|
| **Start reading selection with Polly** | **⌃⌥P** (Control-Option-P) |
| **Stop reading selection with Polly** | **⌃⌥.** (Control-Option-period) |

These work when the app passes selected text to macOS Services (TextEdit, Notes, sometimes Safari). They usually **fail in Chrome/Claude web** and **Electron apps** (Cursor).

## Context menu placement

The installer registers classic **Services** (no `NSIconName`), not Quick Action submenu items. With fewer than about five services enabled for a given context, macOS may show them directly in the right-click menu instead of nesting under **Services**. Disable unused services in **Keyboard Shortcuts → Services** to keep the menu flat.

You cannot add these to the built-in **Speech** submenu (Start Speaking); that menu is reserved for macOS system speech.

## What happens (Start)

1. Selected text is passed as **arguments** to the script (not the clipboard).
2. If `~/.polly-reader-last-voice` matches a known voice, that voice is used **without showing the picker**.
3. On first run (or unknown saved voice), a dialog lists all engines and indexed voices (same layout as `python polly-reader.py --list-voices`).
4. Pick a **numbered voice** row (not an `[engine: …]` heading).
5. Short text is synthesized directly (fast); audio plays via `afplay`.

Set `POLLY_ASK_VOICE=1` before running Start (or in the Automator command) to always show the voice picker. Delete `~/.polly-reader-last-voice` to pick a new default voice on the next run.

The installer sets **Pass input: as arguments** (`"$@"` forwarded to the Start script), omits **NSIconName** (classic Service placement), and disables Automator’s **Show when run** dialog. Your last chosen voice is remembered in `~/.polly-reader-last-voice` and reused automatically on the next run.

## What happens (Stop)

1. Kills any running **`afplay`** process (stops audio immediately).
2. Kills any running **`polly-reader.py`** process (cancels in-progress synthesis).
3. Shows a brief notification if something was stopped; otherwise exits silently.

Stop does not require selected text.

## Manual Automator setup (optional)

If you prefer not to use the installer, create two Quick Actions in Automator:

**Start** — receives **text** in **any application**:

1. **Run Shell Script** → shell `/bin/zsh` → pass input **as arguments**
2. Command:

   ```zsh
   /bin/zsh -f /Users/sbecker11/workspace-aws-polly/polly-reader/scripts/read-selection-with-polly.sh "$@"
   ```

3. Save as **Start reading selection with Polly**

**Stop** — receives **text** in **any application** (input is ignored; required so macOS lists it under **Text**):

1. **Run Shell Script** → shell `/bin/zsh` → pass input **as arguments**
2. Command:

   ```zsh
   /bin/zsh -f /Users/sbecker11/workspace-aws-polly/polly-reader/scripts/stop-reading-with-polly.sh "$@"
   ```

3. Save as **Stop reading selection with Polly**

Use `zsh -f` so Automator does not source `~/.zshenv` (which can break the action with spurious errors).

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| Not in right-click menu | Enable in **Keyboard Shortcuts → Services**; run `pbs -flush`; restart app; disable unused services so items appear inline |
| Stuck under Services submenu | Disable other services until the menu is flat, or use keyboard shortcuts |
| “No text received” | Re-run `./scripts/install-macos-quick-action.sh` (Start workflow must pass `"$@"`); select text before invoking Start |
| ⌃⌥P does nothing in Chrome / Claude | Use `./scripts/install-global-hotkeys.sh` (Shortcuts or skhd); Services do not get web selections |
| ⌃⌥P does nothing in Cursor | Run `./scripts/install-cursor-hotkeys.sh`, reload Cursor |
| Voice picker every time | Last voice is reused silently; set `POLLY_ASK_VOICE=1` to force the picker |
| “Not a voice” | Choose a numbered voice, not an engine heading |
| Stop not in Keyboard → Services | Re-run `./scripts/install-macos-quick-action.sh`; look under **Text** (not General); search "Polly" in the filter box |
| Stop does nothing | Nothing was playing; or run `./scripts/stop-reading-with-polly.sh` in Terminal to verify |
| Slow or errors | Run smoke test in Terminal; check AWS credentials |
| Text too long | Max **10,000** characters |

## Related CLI usage

```bash
python polly-reader.py --list-voices
python polly-reader.py --clipboard --engine neural --voice-id Joanna
killall afplay   # manual stop
```

See [README.md](../README.md) for all input modes.
