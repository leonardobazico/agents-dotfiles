import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import count_tokens


class ParseArgsTests(unittest.TestCase):
    def test_default_level_is_fast(self):
        args = count_tokens.parse_args(["file.txt"])
        self.assertEqual(args.level, "fast")

    def test_tokenizer_implies_exact_level(self):
        args = count_tokens.parse_args(["file.txt", "--tokenizer", "some/repo"])
        self.assertEqual(args.level, "exact")

    def test_exact_without_tokenizer_errors(self):
        with self.assertRaises(SystemExit) as ctx:
            with contextlib.redirect_stderr(io.StringIO()):
                count_tokens.parse_args(["file.txt", "--level", "exact"])
        self.assertEqual(ctx.exception.code, 2)

    def test_tokenizer_conflicts_with_cross_level(self):
        with self.assertRaises(SystemExit) as ctx:
            with contextlib.redirect_stderr(io.StringIO()):
                count_tokens.parse_args(
                    ["file.txt", "--level", "cross", "--tokenizer", "some/repo"]
                )
        self.assertEqual(ctx.exception.code, 2)

    def test_negative_budget_errors(self):
        with self.assertRaises(SystemExit) as ctx:
            with contextlib.redirect_stderr(io.StringIO()):
                count_tokens.parse_args(["file.txt", "--budget", "-1"])
        self.assertEqual(ctx.exception.code, 2)

    def test_zero_budget_is_allowed(self):
        args = count_tokens.parse_args(["file.txt", "--budget", "0"])
        self.assertEqual(args.budget, 0)

    def test_duplicate_stdin_errors(self):
        with self.assertRaises(SystemExit) as ctx:
            with contextlib.redirect_stderr(io.StringIO()):
                count_tokens.parse_args(["-", "-"])
        self.assertEqual(ctx.exception.code, 2)


class ReadSourceTests(unittest.TestCase):
    def test_reads_file_contents(self):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as handle:
            handle.write("hello file")
            path = handle.name
        try:
            self.assertEqual(count_tokens.read_source(path), "hello file")
        finally:
            Path(path).unlink()

    def test_reads_stdin(self):
        with patch("sys.stdin", io.StringIO("hello stdin")):
            self.assertEqual(count_tokens.read_source("-"), "hello stdin")

    def test_missing_file_raises_oserror(self):
        with self.assertRaises(OSError):
            count_tokens.read_source("/no/such/path.txt")


class BuildCounterTests(unittest.TestCase):
    def test_fast_level_counts_with_o200k_encoding(self):
        name, count = count_tokens.build_counter("fast", None)
        self.assertEqual(name, count_tokens.FAST_ENCODING)
        self.assertEqual(count("hello world"), 2)

    def test_cross_level_uses_pinned_repo_and_revision(self):
        calls = []
        encode_calls = []

        class FakeEncoding:
            def __init__(self, text):
                self.ids = text.split()

        class FakeTokenizer:
            @staticmethod
            def encode(text, add_special_tokens):
                encode_calls.append(add_special_tokens)
                return FakeEncoding(text)

        def fake_from_pretrained(repo, revision=None):
            calls.append((repo, revision))
            return FakeTokenizer()

        with patch("tokenizers.Tokenizer.from_pretrained", staticmethod(fake_from_pretrained)):
            name, count = count_tokens.build_counter("cross", None)

        self.assertEqual(name, count_tokens.CROSS_REPO)
        self.assertEqual(calls, [(count_tokens.CROSS_REPO, count_tokens.CROSS_REVISION)])
        self.assertEqual(count("a b c"), 3)
        self.assertEqual(encode_calls, [False])

    def test_exact_level_uses_given_tokenizer_at_main_revision(self):
        calls = []

        class FakeEncoding:
            def __init__(self, text):
                self.ids = text.split()

        class FakeTokenizer:
            @staticmethod
            def encode(text, add_special_tokens):
                return FakeEncoding(text)

        def fake_from_pretrained(repo, revision=None):
            calls.append((repo, revision))
            return FakeTokenizer()

        with patch("tokenizers.Tokenizer.from_pretrained", staticmethod(fake_from_pretrained)):
            name, count = count_tokens.build_counter("exact", "some/repo")

        self.assertEqual(name, "some/repo")
        self.assertEqual(calls, [("some/repo", "main")])
        self.assertEqual(count("a b"), 2)


class MainTests(unittest.TestCase):
    def _write_file(self, text):
        handle = tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False)
        handle.write(text)
        handle.close()
        self.addCleanup(lambda: Path(handle.name).unlink())
        return handle.name

    def test_single_file_prints_count_and_path(self):
        path = self._write_file("hello world")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            exit_code = count_tokens.main([path])
        self.assertEqual(exit_code, count_tokens.EXIT_OK)
        self.assertEqual(out.getvalue(), f"2\t{path}\n")

    def test_multiple_files_prints_total_line(self):
        first = self._write_file("hello world")
        second = self._write_file("hello")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            exit_code = count_tokens.main([first, second])
        self.assertEqual(exit_code, count_tokens.EXIT_OK)
        lines = out.getvalue().splitlines()
        self.assertEqual(lines, [f"2\t{first}", f"1\t{second}", "3\ttotal"])

    def test_json_output_shape(self):
        path = self._write_file("hello world")
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            exit_code = count_tokens.main([path, "--json"])
        self.assertEqual(exit_code, count_tokens.EXIT_OK)
        payload = __import__("json").loads(out.getvalue())
        self.assertEqual(payload["tokenizer"], count_tokens.FAST_ENCODING)
        self.assertEqual(payload["files"], [{"path": path, "tokens": 2}])
        self.assertEqual(payload["total"], 2)
        self.assertFalse(payload["over_budget"])

    def test_budget_within_exits_ok_and_reports_on_stderr(self):
        path = self._write_file("hello world")
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            exit_code = count_tokens.main([path, "--budget", "10"])
        self.assertEqual(exit_code, count_tokens.EXIT_OK)
        self.assertIn("within budget 10", err.getvalue())

    def test_budget_over_exits_over_budget(self):
        path = self._write_file("hello world")
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            exit_code = count_tokens.main([path, "--budget", "1"])
        self.assertEqual(exit_code, count_tokens.EXIT_OVER_BUDGET)
        self.assertIn("OVER budget 1", err.getvalue())

    def test_missing_file_exits_error(self):
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
            exit_code = count_tokens.main(["/no/such/path.txt"])
        self.assertEqual(exit_code, count_tokens.EXIT_ERROR)
        self.assertIn("/no/such/path.txt", err.getvalue())

    def test_tokenizer_load_failure_exits_error(self):
        err = io.StringIO()
        with patch.object(count_tokens, "build_counter", side_effect=RuntimeError("boom")):
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(err):
                exit_code = count_tokens.main(["ignored", "--level", "exact", "--tokenizer", "x"])
        self.assertEqual(exit_code, count_tokens.EXIT_ERROR)
        self.assertIn("cannot load tokenizer", err.getvalue())


if __name__ == "__main__":
    unittest.main()
