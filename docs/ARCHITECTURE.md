# Architecture and maintenance invariants

The root library handles date-only recurrence and inclusive all-day ranges; the CLI
adapts platform argv, validates options, prints output and returns status 0 or 2.

## Data flow

`Rule::parse -> expand / expand_set -> merge_busy / find_conflicts / find_free`.
Callers explicitly turn occurrences into labelled BusySpan values; the library does
not infer event duration. `date.mbt` owns Gregorian epoch-day arithmetic; `rule.mbt`
owns selector parsing; `expand.mbt` owns recurrence counting and window/exception
ordering; `schedule.mbt` owns occupied/free range algebra.

## Important distinctions

- Factories validate dates. Public aggregate construction remains source-compatible;
  expansion now revalidates dates/windows/rules, including mutable selector arrays.
- COUNT counts matching RRULE occurrences from DTSTART, **before** window clipping
  and EXDATE. It does not count only the returned dates and does not reset per query.
- UNTIL and query boundaries are inclusive. RDATE is independent of RRULE COUNT and
  UNTIL; EXDATE removes from both sources. The final output is sorted and unique.
- `limit` is a prefix limit on the final set. At most `limit` surviving rule dates
  are needed: adding dates cannot promote a later rule date into an earlier prefix.
- YEARLY+BYMONTH with no day selector inherits the start day, not the start month.
  YEARLY+BYDAY/BYMONTHDAY without BYMONTH expands over the active year.
- Recurrence skips invalid civil dates; `Date::add_months` is a separate clamping
  operation and is not used to turn January 31 into a February occurrence.
- Period stepping skips inactive periods but visits all eligible days of active
  weeks/months/years. COUNT semantics and the original horizon cap are retained.

## Complexity and limits

Let V be visited active dates, S the bounded selector-list size, E exclusions,
A additions and L output limit. Expansion is O(V*S) plus expected O(E) hash-set
construction and O(A) exception validation. The union sort is O((L+A) log(L+A));
set membership avoids scanning the full exclusion list for every candidate.
Memory is O(E+L+A). The dense horizon is capped at 366001 dates.

Busy-span sorting is O(N log N), with original index as an explicit tie breaker.
The merge sweep is linear in span count apart from label-string construction.
Repeated concatenation of long merged labels may still be quadratic in label size.
Pairwise conflicts remain O(N^2) with potentially quadratic output; no universal
performance claim is made. Inputs are not mutated by merging.

## Verification

See [QUALITY.md](QUALITY.md): independent dateutil oracle, original regression tests,
400-year arithmetic checks, daily occupancy model and real process exit checks.
The CI matrix executes check/build/tests/oracle/CLI on wasm-gc, wasm, js and native.
