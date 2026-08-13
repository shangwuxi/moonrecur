# MoonRecur scope and acceptance

MoonRecur is an original MoonBit library and CLI for deterministic, bounded
civil-calendar recurrence expansion. It targets reusable scheduling logic rather
than wall-clock timers, cron execution, time-zone conversion, or network calendar
synchronization.

## Non-duplication comparison

| Candidate | Domain and core loop | Difference from MoonBench | Difference from MoonContract | Decision |
| --- | --- | --- | --- | --- |
| MoonRecur | Parse recurrence rules and expand civil dates | No timing samples, baselines, or regressions | No HTTP, OpenAPI, schemas, or mocks | Selected: portable, reusable, deterministic |
| MoonLedger | Post double-entry transactions and audit balances | Financial entries rather than timings | Ledgers rather than API interactions | Rejected for this entry: broader policy surface |
| MoonTransit | Parse GTFS tables and route journeys | Timetables rather than benchmark samples | Transit feeds rather than API contracts | Rejected for this entry: large fixture burden |

MoonRecur has a different problem domain, user workflow, core data, algorithms,
outputs, and acceptance demonstration from every reserved project. Shared testing,
CLI, JSON, documentation, and CI practices are engineering infrastructure only.

## Supported behavior

- Gregorian civil dates in years 1 through 9999.
- `DAILY`, `WEEKLY`, `MONTHLY`, and `YEARLY` frequencies.
- `INTERVAL`, `COUNT`, `UNTIL`, `BYDAY`, `BYMONTHDAY`, and `BYMONTH` rule parts.
- Positive and negative month-day selectors.
- Explicit inclusion and exclusion dates.
- Bounded expansion with deterministic ordering and duplicate removal.
- Stable parse and validation diagnostics.
- Human-readable and JSON CLI output.

## Partial behavior

- The syntax follows the useful date-only subset of RFC 5545 RRULE, but is not a
  full iCalendar parser.
- Weekday selectors are supported without numeric ordinals such as `1MO`.
- `WKST` is fixed to Monday for weekly interval grouping.

## Unsupported behavior

- Time of day, time zones, daylight-saving transitions, leap seconds, and duration.
- `BYSETPOS`, `BYYEARDAY`, `BYWEEKNO`, ordinal weekdays, and non-Gregorian calendars.
- Reading or writing `.ics` containers and scheduling operating-system jobs.

## Acceptance flows

1. Expand a weekly Monday/Wednesday rule within a finite date window.
2. Expand month-end and leap-day schedules without producing invalid dates.
3. Apply inclusion and exclusion dates, preserving order and uniqueness.
4. Normalize an equivalent rule into a stable canonical representation.
5. Reject invalid dates, unknown rule parts, conflicting bounds, and expansion
   requests without a finite result limit.
6. Run the same tests under wasm-gc, wasm, JavaScript, and native checks.

## Licensing and dependencies

The project uses Apache-2.0. The implementation is original and uses only the
MoonBit standard library. There are no borrowed code assets or runtime packages.

