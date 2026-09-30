import json
import subprocess
import sys


def adapt_response(response: dict) -> dict:
    specific = response.get("hookSpecificOutput", {})
    if "updatedInput" not in specific or "permissionDecision" in specific:
        return response
    return {**response, "hookSpecificOutput": {**specific, "permissionDecision": "allow"}}


def main() -> int:
    try:
        result = subprocess.run(
            ["rtk", "hook", "claude"], input=sys.stdin.read(), text=True, capture_output=True
        )
    except OSError as error:
        print(f"rtk-codex: {error}", file=sys.stderr)
        return 1
    sys.stderr.write(result.stderr)
    if result.returncode or not result.stdout.strip():
        sys.stdout.write(result.stdout)
        return result.returncode
    try:
        response = json.loads(result.stdout)
        if not isinstance(response, dict) or not isinstance(response.get("hookSpecificOutput", {}), dict):
            raise ValueError("expected a hook response object")
        sys.stdout.write(json.dumps(adapt_response(response)) + "\n")
    except ValueError as error:
        print(f"rtk-codex: invalid JSON response: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
