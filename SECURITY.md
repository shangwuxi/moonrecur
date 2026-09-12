# Security

## Supported version

Security fixes are provided for the latest 0.x release on the default branch.

## Resource boundaries

MoonRecur parses caller-controlled strings and may scan large date ranges. Numeric
rule fields, result limits, year range, and expansion span are bounded. Callers should
still set the smallest practical expansion window and limit. The library performs no
network, filesystem, shell, timezone-database, or code-execution operations.

Do not use recurrence output as an authorization or billing decision without domain
validation. Date-only values intentionally omit timezone and daylight-saving policy.

## Reporting

Before a public security issue tracker exists, report vulnerabilities privately to
the repository owner through GitHub's private vulnerability reporting feature. Do
not include credentials, personal calendar data, or access tokens in reports.

## Maintenance hardening in 0.2.1

Rule text is limited to 8192 UTF-16 units. Decimal accumulation checks for overflow
before multiplication. Each additions/exclusions array is limited to 100000 entries.
Expansion revalidates public dates, windows and mutable selector arrays before use.
The inclusive scan horizon remains at most 366000 days from DTSTART (366001 candidate
dates in the dense case); output limits are applied after exclusions.
find_conflicts intentionally emits all source pairs and remains quadratic: callers
must bound the number of busy spans and the size of a fully overlapping result.
Dates and BusySpan records constructed outside their checked factories remain the
caller's responsibility outside expansion. This is not a sandbox for unlimited input.
