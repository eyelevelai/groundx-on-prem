from __future__ import annotations

import re
from pathlib import Path


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "bin" / "validate-helm.sh"
MAX_LOOKAHEAD = 5

UNITTEST_INVOCATION_PATTERN = re.compile(r"^\s*helm unittest\b")
STABILITY_GUARD_PATTERN = re.compile(r"verify-helm-snapshot-stability\.py\s+verify\b")


def find_unguarded_unittest_invocations(script_text: str, max_lookahead: int = MAX_LOOKAHEAD) -> list[str]:
    lines = script_text.splitlines()
    unguarded: list[str] = []

    for index, line in enumerate(lines):
        if not UNITTEST_INVOCATION_PATTERN.search(line):
            continue
        window = lines[index + 1 : index + 1 + max_lookahead]
        if not any(STABILITY_GUARD_PATTERN.search(candidate) for candidate in window):
            unguarded.append(line.strip())

    return unguarded


def strip_stability_guard_lines(script_text: str) -> str:
    lines = script_text.splitlines()
    remaining = [line for line in lines if "verify-helm-snapshot-stability.py verify" not in line]
    return "\n".join(remaining)


def test_every_helm_unittest_invocation_is_guarded_in_validate_helm():
    script_text = SCRIPT_PATH.read_text(encoding="utf-8")

    unguarded = find_unguarded_unittest_invocations(script_text)

    assert unguarded == []


def test_detector_catches_a_reintroduced_unguarded_invocation():
    script_text = SCRIPT_PATH.read_text(encoding="utf-8")
    regressed_text = strip_stability_guard_lines(script_text)

    unguarded = find_unguarded_unittest_invocations(regressed_text)

    assert unguarded != []


def main() -> int:
    test_every_helm_unittest_invocation_is_guarded_in_validate_helm()
    test_detector_catches_a_reintroduced_unguarded_invocation()
    print("validate-helm structure tests passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
