"""The one place tiktoken and tokenizers are called; callers see one error type."""

from __future__ import annotations

from collections.abc import Callable

Counter = Callable[[str], int]


class TokenizerUnavailableError(Exception):
    pass


class TokenizerLoader:
    def __init__(self, get_encoding, from_pretrained):
        self._get_encoding = get_encoding
        self._from_pretrained = from_pretrained
        self._loads: list[tuple[str, str | None]] = []

    @classmethod
    def create(cls) -> TokenizerLoader:
        return cls(_tiktoken_encoding, _pretrained_tokenizer)

    @classmethod
    def create_null(cls, failure: Exception | None = None) -> TokenizerLoader:
        def stub_returning(tokenizer):
            def load(*_args):
                if failure is not None:
                    raise failure
                return tokenizer

            return load

        return cls(
            stub_returning(_StubTiktokenEncoding()),
            stub_returning(_StubPretrainedTokenizer()),
        )

    def track_loads(self) -> list[tuple[str, str | None]]:
        return self._loads

    def load_encoding(self, name: str) -> Counter:
        self._loads.append((name, None))
        encoding = _translate_failures(lambda: self._get_encoding(name))
        return lambda text: len(encoding.encode(text))

    def load_pretrained(self, repo: str, revision: str) -> Counter:
        self._loads.append((repo, revision))
        loaded = _translate_failures(lambda: self._from_pretrained(repo, revision))
        return lambda text: len(loaded.encode(text, add_special_tokens=False).ids)


def _translate_failures(load):
    try:
        return load()
    except (OSError, ValueError) as error:
        raise TokenizerUnavailableError(str(error)) from error
    except Exception as error:  # noqa: BLE001 - tokenizers raises bare Exception for unparsable files
        raise TokenizerUnavailableError(str(error)) from error


def _tiktoken_encoding(name: str):
    import tiktoken

    return tiktoken.get_encoding(name)


def _pretrained_tokenizer(repo: str, revision: str):
    from tokenizers import Tokenizer

    return Tokenizer.from_pretrained(repo, revision=revision)


class _StubTiktokenEncoding:
    def encode(self, text: str) -> list[str]:
        return text.split()


class _StubEncoded:
    def __init__(self, ids: list[str]):
        self.ids = ids


class _StubPretrainedTokenizer:
    def encode(self, text: str, add_special_tokens: bool = True) -> _StubEncoded:
        words = text.split()
        if add_special_tokens:
            return _StubEncoded(["<s>", *words, "</s>"])
        return _StubEncoded(words)
