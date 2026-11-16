#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["tiktoken>=0.8,<1", "tokenizers>=0.20,<1"]
# ///
"""Count tokens in files or stdin.

Deterministic for a fixed dependency and model revision: both are pinned above.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import TextIO

from tokenizer_loader import TokenizerLoader, TokenizerUnavailableError

FAST_ENCODING = "o200k_base"
CROSS_REPO = "Qwen/Qwen3-8B"
CROSS_REVISION = "b968826d9c46dd6066d109eabc6255188de91218"

EXIT_OK = 0
EXIT_OVER_BUDGET = 1
EXIT_ERROR = 2


def build_counter(level: str, tokenizer: str | None, loader: TokenizerLoader):
    if level == "fast":
        return FAST_ENCODING, loader.load_encoding(FAST_ENCODING)

    repo = tokenizer if level == "exact" else CROSS_REPO
    revision = "main" if level == "exact" else CROSS_REVISION
    return repo, loader.load_pretrained(repo, revision)


def read_source(source: str, stdin: TextIO | None = None) -> str:
    if source == "-":
        return (stdin or sys.stdin).read()
    return Path(source).read_text(encoding="utf-8")


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="count_tokens.py",
        description="Count tokens in files or stdin.",
    )
    parser.add_argument("paths", nargs="+", help="files to count, or - for stdin")
    parser.add_argument(
        "--level",
        choices=("fast", "cross", "exact"),
        default="fast",
        help=(
            f"fast: OpenAI {FAST_ENCODING}. cross: {CROSS_REPO}. "
            "exact: --tokenizer repo."
        ),
    )
    parser.add_argument(
        "--tokenizer", help="HuggingFace repo id, implies --level exact"
    )
    parser.add_argument("--json", action="store_true", help="emit JSON")
    parser.add_argument("--budget", type=int, help="exit 1 when the total exceeds this")
    args = parser.parse_args(argv)

    if args.tokenizer and args.level == "fast":
        args.level = "exact"
    if args.level == "exact" and not args.tokenizer:
        parser.error("--level exact requires --tokenizer")
    if args.tokenizer and args.level == "cross":
        parser.error("--tokenizer conflicts with --level cross")
    if args.budget is not None and args.budget < 0:
        parser.error("--budget must be zero or greater")
    if args.paths.count("-") > 1:
        parser.error("stdin (-) can only be read once")
    return args


def main(argv: list[str], loader: TokenizerLoader | None = None) -> int:
    args = parse_args(argv)
    loader = loader or TokenizerLoader.create()

    try:
        name, count_tokens = build_counter(args.level, args.tokenizer, loader)
    except TokenizerUnavailableError as error:
        print(f"count_tokens: cannot load tokenizer: {error}", file=sys.stderr)
        return EXIT_ERROR

    counts = []
    for source in args.paths:
        try:
            counts.append((source, count_tokens(read_source(source))))
        except (OSError, UnicodeError) as error:
            print(f"count_tokens: {source}: {error}", file=sys.stderr)
            return EXIT_ERROR

    total = sum(tokens for _, tokens in counts)
    over_budget = args.budget is not None and total > args.budget

    if args.json:
        print(
            json.dumps(
                {
                    "tokenizer": name,
                    "level": args.level,
                    "files": [{"path": p, "tokens": t} for p, t in counts],
                    "total": total,
                    "budget": args.budget,
                    "over_budget": over_budget,
                },
                indent=2,
            )
        )
    else:
        for source, tokens in counts:
            print(f"{tokens}\t{source}")
        if len(counts) > 1:
            print(f"{total}\ttotal")

    if args.budget is not None:
        state = "OVER" if over_budget else "within"
        print(f"{state} budget {args.budget} ({total} tokens, {name})", file=sys.stderr)

    return EXIT_OVER_BUDGET if over_budget else EXIT_OK


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
