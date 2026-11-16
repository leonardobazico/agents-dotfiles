import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SUPERPOWERS_SOURCE = "git+https://github.com/obra/superpowers.git#v7.0.2"


class OpenCodeConfigTests(unittest.TestCase):
    def test_native_v2_config_and_plugin_pins(self):
        config = json.loads((ROOT / "harnesses/opencode/opencode.json").read_text())
        self.assertEqual(config["$schema"], "https://opencode.ai/config.json")
        self.assertEqual(
            config["plugins"],
            [f"superpowers@{SUPERPOWERS_SOURCE}"],
        )
        self.assertNotIn("plugin", config)
        self.assertNotIn("permission", config)
        self.assertEqual(
            {
                (rule["action"], rule["resource"], rule["effect"])
                for rule in config["permissions"]
            },
            {
                ("skill", "*", "ask"),
                ("shell", "git commit *", "ask"),
                ("shell", "git push *", "deny"),
                ("shell", "aws *", "deny"),
                ("external_directory", "*", "ask"),
            },
        )

    def test_opencode_manifest_versions_and_install_modes(self):
        rows = {
            tuple(line.split("\t"))
            for line in (ROOT / "plugins/manifest.tsv").read_text().splitlines()
            if line and not line.startswith("#")
        }
        self.assertIn(
            ("superpowers", "opencode", SUPERPOWERS_SOURCE, "manual"),
            rows,
        )
        self.assertIn(
            ("i-have-adhd", "opencode", "ayghri/i-have-adhd@v0.4.1", "auto"),
            rows,
        )


if __name__ == "__main__":
    unittest.main()
