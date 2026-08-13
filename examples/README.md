# MoonRecur examples

Run these commands from the repository root.

## Normalize and validate

```sh
moon run cmd/moonrecur -- validate --rule "BYDAY=WE,MO;COUNT=4;FREQ=WEEKLY"
moon run cmd/moonrecur -- explain --rule "FREQ=MONTHLY;BYMONTHDAY=-1"
```

## Expand with exceptions

```sh
moon run cmd/moonrecur -- expand \
  --start 2026-08-03 \
  --rule "FREQ=WEEKLY;BYDAY=MO,WE;COUNT=6" \
  --from 2026-08-01 \
  --through 2026-09-01 \
  --rdate 2026-08-07 \
  --exdate 2026-08-05
```

The command prints a deterministic, ordered set. Repeated additions are
deduplicated and exclusions take precedence.

## Invalid input

```sh
moon run cmd/moonrecur -- validate --rule "FREQ=MONTHLY;BYMONTHDAY=0"
```

The process returns exit code 2 and a stable `rule.value.range` diagnostic.
