# Changelog

All notable changes are recorded here. The project follows Semantic Versioning.

## 0.2.1 - 2026-09-12

Maintenance release; the public library interface is unchanged.

- Correct YEARLY selector expansion: explicit BYMONTH inherits only the day;
  BYDAY/BYMONTHDAY without BYMONTH may expand throughout the year.
- Apply EXDATE before the output limit without changing RRULE COUNT semantics;
  sort/de-duplicate RDATE unions without insertion-sort growth.
- Reject integer wraparound, oversized rule text, invalid public aggregate inputs,
  oversized exception arrays, ambiguous CLI options, and hidden unknown commands.
- Skip inactive frequency periods; preserve month-end skipping rather than clamping.
- Replace busy-span insertion sorting while preserving equal-span label order.
- Add 800 pinned dateutil comparison cases (baseline: 108 failures; now: zero),
  a full 400-year calendar cycle and 200 generated occupancy models.
- Verify 66 test groups, 800 oracle cases and 10 real CLI cases per CI target.

Behavior changes are correctness fixes; callers relying on previously accepted
malformed options or erroneous annual/exclusion output must update expectations.

## 0.2.0 - 2026-08-25

- Add `conflicts` CLI analysis for repeated inclusive all-day busy spans.
- Add `free` CLI analysis with window clipping, merge normalization, and empty-set
  handling.
- Add strict busy-span diagnostics, command tests, runnable examples, and CI
  acceptance flows.

## 0.1.0 - 2026-08-13

- Add validated Gregorian date arithmetic for years 1 through 9999.
- Add strict parsing and canonicalization for the documented recurrence profile.
- Add bounded DAILY, WEEKLY, MONTHLY, and YEARLY expansion.
- Add occurrence additions/exclusions and deterministic set normalization.
- Add all-day conflict, busy-merge, and free-range analysis.
- Add portable validate, explain, and expand CLI commands.
- Add multi-target checks, tests, examples, documentation, and disclosures.
