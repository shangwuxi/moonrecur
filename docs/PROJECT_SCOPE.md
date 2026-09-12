# MoonRecur maintenance scope

This work maintains the existing public MoonRecur project, starting from commit
`aa2f5a3` (0.2.0). It is not a new-project ecosystem-gap submission.

## Maintenance objectives

1. Correct yearly selector inheritance and recurrence-set limit ordering.
2. Harden integer parsing, public aggregate inputs and CLI argument validation.
3. Reduce unnecessary candidate visits and insertion-sort work without changing API
   signatures or date-only scope.
4. Establish an independent pinned oracle, focused regressions, calendar/range
   invariants and four-target process-level CI.
5. Document reproducible before/after evidence and remaining limitations.

See [QUALITY.md](QUALITY.md) for measurements and [SUPPORTED_RRULE.md](SUPPORTED_RRULE.md)
for compatibility. This maintenance task does not claim an empty ecosystem or
submission eligibility under a particular competition track. It does not add time
zones, cron execution, calendar network services or complete RFC 5545 support.
