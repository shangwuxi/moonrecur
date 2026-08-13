# MoonRecur

MoonRecur is an original MoonBit library and CLI for deterministic, bounded
civil-calendar recurrence expansion. It parses a documented date-only profile of
RFC 5545 RRULE values, expands occurrences, applies RDATE/EXDATE-style exception
sets, and analyzes all-day schedules for conflicts and free ranges.

It is designed for reminder apps, booking tools, offline planners, static-site
generators, and any MoonBit program that needs portable recurrence behavior without
a timezone database or network service.

## What it supports

- Gregorian dates from year 1 through 9999, including checked arithmetic.
- `DAILY`, `WEEKLY`, `MONTHLY`, and `YEARLY` frequency.
- `INTERVAL`, `COUNT`, `UNTIL`, `BYDAY`, `BYMONTHDAY`, and `BYMONTH`.
- Negative month days such as `BYMONTHDAY=-1` for the last day of a month.
- Inclusive expansion windows, result limits, sorted de-duplication, additions, and
  exclusions.
- Inclusive all-day busy spans, pairwise conflict detection, merging, and free-range
  discovery.
- Stable diagnostic codes and a portable CLI command layer.

This is deliberately not a complete iCalendar parser. It does not handle time of
day, timezone transitions, `.ics` containers, CalDAV, ordinal weekdays, or the
unsupported rule fields listed in [the support matrix](docs/SUPPORTED_RRULE.md).

## Install and verify

MoonRecur currently requires the MoonBit toolchain used by the repository CI.

Clone the public repository and resolve its dependency:

```sh
git clone https://github.com/shangwuxi/moonrecur.git
cd moonrecur
moon update
moon test --target wasm-gc
```

To reproduce the complete engineering gate, run:

```sh
moon fmt --check
moon check --target wasm-gc --deny-warn
moon check --target wasm --deny-warn
moon check --target js --deny-warn
moon check --target native --deny-warn
moon test --target wasm-gc
moon test --target native
```

Native execution additionally needs a C compiler. CI supplies one on Ubuntu.

## CLI examples

Validate and normalize a rule:

```sh
moon run cmd/moonrecur --target js -- validate \
  --rule 'BYDAY=WE,MO;COUNT=4;FREQ=WEEKLY'
```

```text
valid: FREQ=WEEKLY;COUNT=4;BYDAY=MO,WE
```

Expand a month-end schedule. February and April are skipped because the 31st does
not exist:

```sh
moon run cmd/moonrecur --target js -- expand \
  --start 2024-01-31 --rule 'FREQ=MONTHLY;COUNT=3' \
  --from 2024-01-01 --through 2024-06-30
```

```text
occurrences: 3
2024-01-31
2024-03-31
2024-05-31
```

Invalid input produces a stable diagnostic and exits with code 2:

```sh
moon run cmd/moonrecur --target js -- validate \
  --rule 'FREQ=MONTHLY;BYMONTH=13'
```

## Library example

```moonbit
let start = @moonrecur.Date::parse("2026-08-03").unwrap()
let rule = @moonrecur.Rule::parse(
  "FREQ=WEEKLY;COUNT=4;BYDAY=MO,WE",
).unwrap()
let window = @moonrecur.ExpansionWindow::make(
  @moonrecur.Date::parse("2026-08-01").unwrap(),
  @moonrecur.Date::parse("2026-08-31").unwrap(),
  100,
).unwrap()
let dates = @moonrecur.expand(start, rule, window).unwrap()
println(@moonrecur.dates_to_lines(dates))
```

The generated public interface is in [`pkg.generated.mbti`](pkg.generated.mbti).
Runnable command recipes and expected outputs are in [`examples`](examples).

## Design and project records

- [Architecture](docs/ARCHITECTURE.md)
- [Supported RRULE profile](docs/SUPPORTED_RRULE.md)
- [Scope, acceptance, and originality review](docs/PROJECT_SCOPE.md)
- [Security and resource limits](SECURITY.md)
- [Third-party attribution](THIRD_PARTY.md)
- [AI assistance disclosure](AI_USAGE.md)
- [Contributing](CONTRIBUTING.md)
- [Changelog](CHANGELOG.md)

## License

Apache-2.0. See [`LICENSE`](LICENSE).
