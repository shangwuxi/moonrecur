#!/usr/bin/env python3
"""Replay small, explicit maintenance witnesses through actual CLI processes."""
import argparse
import json
import pathlib
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
BASELINE = "aa2f5a3405483d35d413aa4aa2f96a519c4919ed"


def expansion(rule, start, through, *extra):
    return ["expand", "--start", start, "--rule", rule,
            "--from", start, "--through", through] + list(extra)


def cases():
    return [
        ("yearly-explicit-month", expansion("FREQ=YEARLY;BYMONTH=2,6;COUNT=2", "2024-01-15", "2024-12-31"),
         0, "occurrences: 2\n2024-02-15\n2024-06-15"),
        ("yearly-weekday-across-months", expansion("FREQ=YEARLY;BYDAY=MO;COUNT=2", "2024-01-30", "2024-03-01"),
         0, "occurrences: 2\n2024-02-05\n2024-02-12"),
        ("yearly-monthday-across-months", expansion("FREQ=YEARLY;BYMONTHDAY=1;COUNT=2", "2024-01-15", "2024-03-01"),
         0, "occurrences: 2\n2024-02-01\n2024-03-01"),
        ("exclude-before-limit", expansion("FREQ=DAILY;COUNT=5", "2026-01-01", "2026-01-10", "--limit", "2", "--exdate", "2026-01-01", "--exdate", "2026-01-02"),
         0, "occurrences: 2\n2026-01-03\n2026-01-04"),
        ("rule-integer-wraparound", ["validate", "--rule", "FREQ=DAILY;COUNT=4294967297"],
         2, "rule.integer.overflow at COUNT: integer exceeds the supported magnitude (expected at most 2147483647, got 4294967297)"),
        ("unknown-command-prefix", ["nonsense", "validate", "--rule", "FREQ=DAILY"],
         2, "unknown command: nonsense"),
        ("cli-limit-wraparound", expansion("FREQ=DAILY", "2026-01-01", "2026-01-10", "--limit", "4294967297"),
         2, "--limit exceeds integer range"),
        ("duplicate-singleton-option", ["validate", "--rule", "FREQ=DAILY", "--rule", "FREQ=WEEKLY"],
         2, "duplicate option: --rule"),
    ]


def replay(root, argv, target, status, output, match_mode):
    command = ["moon", "run", "cmd/moonrecur", "--target", target, "--"] + argv
    result = subprocess.run(command, cwd=str(root), capture_output=True,
                            encoding="utf-8", timeout=120)
    # A toolchain/build failure must never count as a reproduced old defect.
    if result.returncode not in (0, 2) or "error:" in result.stderr.lower():
        raise RuntimeError("CLI could not execute: " + result.stderr)
    actual = result.stdout.strip()
    output_matches = actual == output if match_mode == "exact" else actual.startswith(output + "\n\nMoonRecur ")
    return {"exit_code": result.returncode, "stdout": actual,
            "matches_expected": result.returncode == status and output_matches}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-root", type=pathlib.Path)
    parser.add_argument("--target", default="js", choices=["js", "wasm", "wasm-gc", "native"])
    parser.add_argument("--report", type=pathlib.Path, required=True)
    args = parser.parse_args()
    rows = []
    for name, argv, status, output in cases():
        match_mode = "diagnostic-with-help" if name == "unknown-command-prefix" else "exact"
        row = {"id": name, "stdout_match": match_mode, "argv": argv, "expected_exit_code": status, "expected_stdout": output,
               "current": replay(ROOT, argv, args.target, status, output, match_mode)}
        if args.baseline_root:
            row["baseline"] = replay(args.baseline_root.resolve(), argv, args.target, status, output, match_mode)
        rows.append(row)
    report = {"baseline_reference": BASELINE if args.baseline_root else None,
              "target": args.target, "cases": rows,
              "current_passed": sum(r["current"]["matches_expected"] for r in rows),
              "total": len(rows)}
    if args.baseline_root:
        report["baseline_passed"] = sum(r["baseline"]["matches_expected"] for r in rows)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("Maintenance witnesses: %d/%d current passed" % (report["current_passed"], len(rows)))
    if args.baseline_root:
        print("Baseline matches: %d/%d" % (report["baseline_passed"], len(rows)))
    if report["current_passed"] != len(rows):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
