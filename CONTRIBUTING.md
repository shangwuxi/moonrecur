# Contributing

Open an issue before changing recurrence semantics so supported behavior remains
explicit. Keep the root library portable and return stable diagnostics for rejected
inputs. New syntax needs positive, negative, boundary, canonicalization, and
cross-frequency tests plus an update to `docs/SUPPORTED_RRULE.md`.

Run before submitting a change:

```sh
moon update
moon info
moon fmt --check
moon check --target wasm-gc --deny-warn
moon check --target wasm --deny-warn
moon check --target js --deny-warn
moon check --target native --deny-warn
moon test --target wasm-gc
```

Native tests require a C compiler. Contributions are accepted under Apache-2.0 as
described by the repository license.
