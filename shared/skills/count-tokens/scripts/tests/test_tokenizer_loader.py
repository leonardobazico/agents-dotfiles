import unittest

from tokenizer_loader import TokenizerLoader, TokenizerUnavailableError


class RealTokenizerLoaderTests(unittest.TestCase):
    def test_encoding_counts_with_tiktoken(self):
        count = TokenizerLoader.create().load_encoding("o200k_base")
        self.assertEqual(count("hello world"), 2)

    def test_unknown_encoding_is_unavailable(self):
        with self.assertRaises(TokenizerUnavailableError):
            TokenizerLoader.create().load_encoding("no_such_encoding")


class NullTokenizerLoaderTests(unittest.TestCase):
    def test_encoding_counts_words(self):
        count = TokenizerLoader.create_null().load_encoding("o200k_base")
        self.assertEqual(count("a b c"), 3)

    def test_pretrained_counts_words_without_special_tokens(self):
        count = TokenizerLoader.create_null().load_pretrained("some/repo", "main")
        self.assertEqual(count("a b c"), 3)

    def test_tracks_each_load(self):
        loader = TokenizerLoader.create_null()
        loads = loader.track_loads()
        loader.load_encoding("o200k_base")
        loader.load_pretrained("some/repo", "abc123")
        self.assertEqual(loads, [("o200k_base", None), ("some/repo", "abc123")])

    def test_library_failures_become_unavailable(self):
        for failure in [
            OSError("offline"),
            ValueError("unknown encoding"),
            Exception("unparsable tokenizer file"),
        ]:
            with self.subTest(failure=failure):
                loader = TokenizerLoader.create_null(failure=failure)
                with self.assertRaises(TokenizerUnavailableError) as ctx:
                    loader.load_pretrained("some/repo", "main")
                self.assertIs(ctx.exception.__cause__, failure)
                self.assertIn(str(failure), str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
