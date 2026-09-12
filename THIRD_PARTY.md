# Third-party notices

MoonRecur's implementation, tests, examples, and documentation are original.

The CLI uses `moonbitlang/x` version 0.4.49, maintained by the MoonBit project and
distributed under the Apache License 2.0. Only its `sys` package is imported to set
portable process exit codes. The MoonBit compiler, standard library, and GitHub
Actions setup action are development/build tooling and are not copied into this
repository.

There are no borrowed images, generated datasets, or bundled third-party source
assets. RFC 5545 terminology is referenced as a public interoperability standard;
MoonRecur is an original implementation, not a source port.

## Independent test oracle

python-dateutil 2.9.0.post0 (https://github.com/dateutil/dateutil,
https://dateutil.readthedocs.io/en/stable/rrule.html) is a test-only dependency,
dual licensed under Apache-2.0 and BSD-3-Clause. Its implementation is not copied,
translated, or shipped in MoonRecur. scripts/compare_dateutil.py generates original
seeded inputs, invokes the installed package, and compares occurrence output.
The core library does not depend on Python, dateutil, or a timezone database.
RFC 5545 section 3.3.10 is a normative reference, not a claim of full compliance.
