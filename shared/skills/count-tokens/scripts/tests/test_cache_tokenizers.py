import contextlib
import io
import unittest

import cache_tokenizers
from count_tokens import CROSS_REPO, CROSS_REVISION, FAST_ENCODING
from tokenizer_loader import TokenizerLoader


class CacheTokenizersTests(unittest.TestCase):
    def test_loads_default_tokenizers_and_extra_repos(self):
        loader = TokenizerLoader.create_null()
        loads = loader.track_loads()
        with contextlib.redirect_stdout(io.StringIO()):
            exit_code = cache_tokenizers.main(["extra/repo"], loader)
        self.assertEqual(exit_code, 0)
        self.assertEqual(
            loads,
            [
                (FAST_ENCODING, None),
                (CROSS_REPO, CROSS_REVISION),
                ("extra/repo", "main"),
            ],
        )

    def test_failures_are_reported_and_exit_non_zero(self):
        loader = TokenizerLoader.create_null(failure=OSError("offline"))
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            exit_code = cache_tokenizers.main([], loader)
        self.assertEqual(exit_code, 1)
        self.assertIn(f"FAILED tiktoken/{FAST_ENCODING}: offline", err.getvalue())
        self.assertIn(f"FAILED {CROSS_REPO}: offline", err.getvalue())


if __name__ == "__main__":
    unittest.main()
