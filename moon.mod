// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "Han-Wentao/moonrecur"

version = "0.1.0"

readme = "README.md"

repository = ""

license = "Apache-2.0"

keywords = [ "calendar", "recurrence", "rrule", "scheduling" ]

preferred_target = "wasm-gc"

description = "Deterministic civil-calendar recurrence expansion for MoonBit"

import {
  "moonbitlang/x@0.4.49",
}
