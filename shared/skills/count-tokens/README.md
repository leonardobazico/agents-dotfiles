# count-tokens

Deterministic token counting. The skill is thin on purpose: all logic lives in
`scripts/count_tokens.py` so repeated runs return the same number.

Determinism holds for a fixed dependency and model revision. Dependencies carry upper
bounds and the `cross` tokenizer is pinned to an explicit HuggingFace revision, so an
upstream push cannot silently change your counts. A tokenizer passed via `--tokenizer` is
unpinned and tracks its repo's `main`.

## The Claude gap, first

No tokenizer here is Anthropic's. Anthropic does not publish one for Claude 3 or later.
The reference column below is `Xenova/claude-tokenizer`, a Claude 2-era vocabulary and the
closest public stand-in available. It is itself an approximation of current Claude models,
so treat the gap as an order of magnitude, not a calibration constant.

Measured against that reference, every built-in tokenizer in this skill reads
**8 to 13 percent low**:

| Corpus | o200k (OpenAI) | cl100k (OpenAI) | Qwen3 | Claude-family reference | `chars / 4` |
| --- | --- | --- | --- | --- | --- |
| Markdown with tables | 2283 | 2276 | 2278 | 2494 | 2654 |
| Makefile | 984 | 976 | 977 | 1121 | 817 |
| Python source | 348 | 342 | 356 | 394 | 253 |
| Deviation from reference | -8.5% to -12.2% | -8.7% to -13.2% | -8.7% to -9.6% | baseline | +6.4% to -35.8% |

Method: each corpus was encoded with every tokenizer in one pass, special tokens
disabled, and each deviation is `count / reference - 1`. The corpora were this repository's
`shared/agents-md/AGENTS.md` (markdown with tables), its `Makefile` (config), and a short Python
script. Absolute counts come from a fixed sample taken when this skill was written, not from
live repository files; those files change, the deviation pattern does not. The percentages
are the finding, not the raw numbers.

The gap is measured only for the built-in `fast` and `cross` tokenizers. A tokenizer
supplied through `--tokenizer` is unmeasured, and no claim here extends to it.

Counts are reported raw, with no correction factor applied. A calibration multiplier would
make the output match no real tokenizer, and it would stack a fudge factor on top of an
approximation that is itself imperfect.

Practical rule: when budgeting against a Claude limit, treat a reading of 2,283 as
potentially 2,500 and leave headroom. A file that measures just under a cap here can be
over it in Claude terms.

The last column is why this skill exists. `chars / 4` does not degrade predictably. It
overshoots on prose and undershoots on code by more than a third, so it cannot be trusted
for either.

## Three levels

| Level | Tokenizer | Cost | Use it when |
| --- | --- | --- | --- |
| `fast` (default) | OpenAI `o200k_base` via `tiktoken` | pip only, about 1ms | everyday budget checks; representative of the whole modern-BPE cluster |
| `cross` | `Qwen/Qwen3-8B` via `tokenizers` | one-time download, about 11MB | confirming `fast` with a second family, or targeting Qwen |
| `exact` | a HuggingFace repo publishing `tokenizer.json`, via `--tokenizer` | varies | budgeting for one specific named model |

OpenAI and Qwen agree within roughly 1 to 2 percent on every corpus tested, so `cross` is a
confirmation step rather than a more accurate one. Reach for `exact` when the target model
is known and its tokenizer is published.

`exact` requires the repo to publish a `tokenizer.json` at its root. Repos that ship a
different format (Kimi, below) fail with exit code 2 rather than counting. Each `exact` repo
must also be cached separately before it will work offline.

Kimi was evaluated and dropped. It ships no `tokenizer.json`, so loading it means either
executing Moonshot's `tokenization_kimi.py` at count time or rebuilding the encoding by
scraping a regex out of that file. Its counts sat within 1 percent of OpenAI and Qwen, so
neither cost bought any information.

## Pre-caching

`fast` needs no download. `cross` and `exact` fetch from HuggingFace on first use.

```bash
make cache-tokenizers
```

This caches the built-in tokenizers into `~/.cache/huggingface`. Pass extra repo ids to
cache those too:

```bash
shared/skills/count-tokens/scripts/cache_tokenizers.py Qwen/Qwen2.5-7B
```

Once cached, `HF_HUB_OFFLINE=1` works for every level.

## Testing

```bash
shared/skills/count-tokens/scripts/run_tests.sh
```

Runs the `unittest` suite in `scripts/tests/` via `uv run`, with `tiktoken` and
`tokenizers` supplied as ephemeral dependencies.
