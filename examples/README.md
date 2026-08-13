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
