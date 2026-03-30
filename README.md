# polly-reader

Reads text from one of several sources, sends it to Amazon Polly for synthesis, downloads the result from S3, and plays the audio locally (platform-dependent).

## Requirements

- Python 3 with dependencies from `requirements.txt` (e.g. `boto3`)
- AWS credentials and permissions for Polly and the configured S3 bucket
- For clipboard input on **Linux**: `xclip` or `xsel` (optional; see below)

## Text input (choose exactly one)

You must supply **exactly one** of the following. Combining them (for example a `.txt` path **and** `--clipboard`) is an error.

| Modality | How | Typical use |
|----------|-----|-------------|
| **File** | Positional `textfile` | `python polly-reader.py article.txt` |
| **Literal** | `--text "..."` | Short phrases; quote text for the shell |
| **Standard input** | `--stdin` | Pipes and redirects; paste on macOS often via `pbpaste` |
| **Clipboard** | `--clipboard` | Copy text elsewhere, then run without a file argument |

### File (`textfile`)

- Path to an existing **UTF-8** file whose name ends in **`.txt`**.
- Example: `python polly-reader.py notes.txt --engine neural --voice-id Joanna`

### Literal (`--text`)

- Pass the string on the command line after `--text`.
- Best for short content; long pasted paragraphs are awkward because of shell quoting and length limits.
- Example: `python polly-reader.py --text "Hello from Polly."`

### Standard input (`--stdin`)

- Reads the entire stream until EOF, then trims leading/trailing whitespace.
- Examples:
  - `pbpaste | python polly-reader.py --stdin`
  - `python polly-reader.py --stdin < notes.txt`
  - `python polly-reader.py --stdin` then type or paste, then **Ctrl+D** (Unix) to end input

### Clipboard (`--clipboard`)

- **macOS:** uses `pbpaste` (no extra install).
- **Linux:** tries `xclip -selection clipboard -o`, then `xsel -b -o`. If neither exists, use `--stdin` with a pipe instead.
- **Windows:** not supported for `--clipboard`; use `--stdin` or a `.txt` file.
- Example: `python polly-reader.py --clipboard --engine neural`

### Text length

After reading from any modality, the text must be non-empty and between **2** and **10,000** characters (inclusive), after strip.

## Other useful options

- `--engine` — `standard`, `neural`, or `long-form` (must match Polly; invalid values produce a clear error).
- `--voice-id` — must be valid for the chosen `--engine` (see error message if not).
- `--region`, `--bucket`, `--prefix`, `--output-format`, `--output-file` — AWS and output tuning; see `python polly-reader.py --help`.

## Help

```bash
python polly-reader.py --help
```
