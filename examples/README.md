# Runnable examples

Run these commands from the repository root after `moon update`.

## Normalize a weekly rule

```sh
moon run cmd/moonrecur --target js -- validate --rule "BYDAY=WE,MO;COUNT=4;FREQ=WEEKLY"
```

Expected output is stored in `weekly.expected.txt`.

## Expand a leap-year month-end rule

```sh
moon run cmd/moonrecur --target js -- expand --start 2024-01-31 --rule "FREQ=MONTHLY;COUNT=3" --from 2024-01-01 --through 2024-06-30
```

Expected output is stored in `month-end.expected.txt`.

## Observe a stable invalid-input diagnostic

```sh
moon run cmd/moonrecur --target js -- validate --rule "FREQ=MONTHLY;BYMONTH=13"
```

The command exits with status 2. Expected output is stored in
`invalid-month.expected.txt`.

## Detect overlapping all-day spans

```sh
moon run cmd/moonrecur --target js -- conflicts --busy "release:2026-08-10..2026-08-12" --busy "review:2026-08-12..2026-08-13" --busy "travel:2026-08-20..2026-08-21"
```

Expected output is stored in `conflicts.expected.txt`.

## Find free all-day ranges

```sh
moon run cmd/moonrecur --target js -- free --from 2026-08-01 --through 2026-08-10 --busy "before:2026-07-20..2026-08-02" --busy "middle:2026-08-05..2026-08-06" --busy "after:2026-08-10..2026-08-20"
```

Expected output is stored in `free.expected.txt`.
