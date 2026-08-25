# Architecture

MoonRecur keeps calendar policy in a portable root library and process behavior in a
thin executable package.

1. `date.mbt` validates Gregorian dates and converts them to/from epoch-day values.
2. `rule.mbt` parses the supported recurrence-property profile into a validated AST
   and renders canonical field/list order.
3. `expand.mbt` scans a bounded civil-date range, tests period/selector eligibility,
   applies COUNT/UNTIL, and normalizes additions and exclusions.
4. `schedule.mbt` turns occurrences into inclusive busy spans and provides conflict,
   merge, and free-range algorithms.
5. `command.mbt` maps portable command arguments to recurrence and schedule library
   calls, including strict `LABEL:START..END` busy-span parsing. The executable in
   `cmd/moonrecur` only reads process arguments, prints output, and applies exit codes.

## Invariants

- A `Date` always represents a real Gregorian day in years 1 through 9999.
- A parsed `Rule` has exactly one supported frequency, positive bounded numeric
  controls, no duplicate fields, and no simultaneous COUNT/UNTIL.
- Expansion always has a caller window and result limit. A 366,000-day scan guard
  bounds work even when a selector never matches.
- Occurrences are ascending and unique after exception-set normalization.
- Busy and free spans use inclusive all-day endpoints. Adjacent busy spans merge.
- Diagnostics expose stable codes and fields; prose may improve without breaking
  integrations.

## Complexity

Expansion is `O(D * S)` where `D` is the number of scanned days and `S` is the small
selector count. This straightforward evaluator favors auditability over speculative
indexing and is capped by the scan guard. Pairwise conflict discovery is `O(N^2)` to
preserve every source pair. Busy merging and free-range analysis use insertion sort
plus a linear sweep, suitable for the small offline schedules in scope.

## Portability

The root library uses the MoonBit standard library. The CLI imports
`moonbitlang/x/sys` only for a portable process exit code. Tests run on wasm-gc, and
strict checks cover wasm-gc, wasm, JavaScript, and native. GitHub Actions additionally
executes native tests and the native CLI on Ubuntu.
