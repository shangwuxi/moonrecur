# Supported recurrence profile

MoonRecur accepts an RFC 5545-inspired, date-only recurrence-property value. Field
names and enum values are uppercase and properties are separated by semicolons.

| Field | Support | Constraints |
| --- | --- | --- |
| `FREQ` | Full in profile | Required; `DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY` |
| `INTERVAL` | Full in profile | `1..10000`; defaults to 1 |
| `COUNT` | Full in profile | `1..100000`; mutually exclusive with `UNTIL` |
| `UNTIL` | Full in profile | Inclusive `YYYY-MM-DD`; mutually exclusive with `COUNT` |
| `BYDAY` | Partial | Plain weekday tokens only; DAILY combination rejected |
| `BYMONTHDAY` | Full in profile | `-31..-1` or `1..31`; nonexistent dates are skipped |
| `BYMONTH` | Full in profile | `1..12` |
| `WKST` | Fixed behavior | Monday; explicit field rejected to prevent false claims |
| `BYSETPOS`, `BYYEARDAY`, `BYWEEKNO` | Unsupported | Stable `rule.field.unsupported` diagnostic |
| `BYSECOND`, `BYMINUTE`, `BYHOUR` | Unsupported | Date-only profile |
| `SECONDLY`, `MINUTELY`, `HOURLY` | Unsupported | Stable `rule.frequency.unsupported` diagnostic |

Selector lists are de-duplicated and canonicalized. Negative `BYMONTHDAY` values
count backward from month end. When a monthly or yearly rule has no BY selector, the
start day/month is inherited; years or months where that civil date does not exist do
not emit an occurrence.

## Intentional differences from full RFC 5545

MoonRecur parses an RRULE value, not an iCalendar content line or `.ics` object.
Floating date-times, UTC values, timezone identifiers, ordinal weekday selectors,
week numbers, year days, and BYSETPOS expansion are outside version 0.2.1. Unknown or
unsupported behavior fails explicitly instead of being silently ignored.

## Maintenance clarifications (0.2.1)

YEARLY with BYMONTH alone inherits the DTSTART day in each selected month. YEARLY
with BYDAY or BYMONTHDAY but without BYMONTH may expand throughout each active year.
COUNT is applied before clipping and exceptions; the output limit applies after
EXDATE and RDATE union. RDATE is not restricted by the rule COUNT or UNTIL.

The parser still accepts BYMONTHDAY with WEEKLY as a date-filter extension even
though RFC 5545 prohibits that combination. It is not part of the dateutil
conformance corpus and is not advertised as RFC compliance. DAILY+BYDAY remains
explicitly unsupported in this version. UNTIL uses YYYY-MM-DD, not basic DATE syntax.
See QUALITY.md for the exact common subset compared with python-dateutil.
