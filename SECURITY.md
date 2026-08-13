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
