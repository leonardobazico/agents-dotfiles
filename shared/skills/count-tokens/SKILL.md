---
name: count-tokens
description: Use when a token count, context budget, or size cap matters - checking whether a file fits a limit, comparing prompt or document sizes, or trimming content to a target. Also use when about to estimate tokens from character or word count.
---

# count-tokens

Estimating tokens from character or word count is unreliable: on mixed content the
`chars / 4` rule lands anywhere from 6 percent over to 36 percent under. Run the script.

## Usage

```bash
shared/skills/count-tokens/scripts/count_tokens.py <path>...
```

`uv` resolves dependencies on first run. No setup step.

| Flag | Effect |
| --- | --- |
| `--level fast` | Default. OpenAI `o200k_base`, no download. |
| `--level cross` | `Qwen/Qwen3-8B`, second tokenizer family. |
| `--tokenizer <hf-repo>` | Count with a specific model's tokenizer. |
| `--budget N` | Exit 1 when the total exceeds N. |
| `--json` | Machine-readable output. |

Pass `-` as the path to read stdin.

## Output contract

Default output is one `<tokens>\t<path>` line per file, plus a `total` line when given
more than one file. Budget verdicts go to stderr, so stdout stays parseable.

Exit codes: `0` within budget, `1` over budget, `2` bad usage or unreadable input.

Tokenizer choice, accuracy caveats, and pre-caching: see `README.md`.
