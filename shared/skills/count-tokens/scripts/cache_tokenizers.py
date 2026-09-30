#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["tiktoken>=0.8,<1", "tokenizers>=0.20,<1"]
# ///
"""Pre-download every tokenizer count_tokens.py can use, so later runs work offline.

Tokenizer identities are imported from count_tokens.py rather than repeated here, so the
two scripts cannot drift apart.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))

import tiktoken
from count_tokens import CROSS_REPO, CROSS_REVISION, FAST_ENCODING
from tokenizers import Tokenizer

DEFAULT_REVISION = "main"


def main(argv: list[str]) -> int:
    failed = False

    try:
        tiktoken.get_encoding(FAST_ENCODING)
        print(f"cached tiktoken/{FAST_ENCODING}")
    except Exception as error:
        print(f"FAILED tiktoken/{FAST_ENCODING}: {error}", file=sys.stderr)
        failed = True

    repos = [(CROSS_REPO, CROSS_REVISION)] + [(repo, DEFAULT_REVISION) for repo in argv]
    for repo, revision in repos:
        try:
            Tokenizer.from_pretrained(repo, revision=revision)
            print(f"cached {repo}")
        except Exception as error:
            print(f"FAILED {repo}: {error}", file=sys.stderr)
            failed = True

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
