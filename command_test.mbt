///|
test "CLI validates and explains canonical rules" {
  let valid = @moonrecur.execute([
    "validate", "--rule", "BYDAY=WE,MO;COUNT=4;FREQ=WEEKLY",
  ])
  assert_eq(valid.exit_code, 0)
  assert_eq(valid.output, "valid: FREQ=WEEKLY;COUNT=4;BYDAY=MO,WE")
  let explained = @moonrecur.execute([
    "explain", "--rule", "FREQ=MONTHLY;BYMONTHDAY=-1",
  ])
  assert_eq(explained.exit_code, 0)
  assert_true(explained.output.contains("termination: caller window"))
}

///|
test "CLI expands a real recurrence flow" {
  let result = @moonrecur.execute([
    "expand", "--start", "2024-01-31", "--rule", "FREQ=MONTHLY;COUNT=3", "--from",
    "2024-01-01", "--through", "2024-06-30",
  ])
  assert_eq(result.exit_code, 0)
  assert_eq(result.output, "occurrences: 3\n2024-01-31\n2024-03-31\n2024-05-31")
}

///|
test "CLI applies repeated inclusion and exclusion options" {
  let result = @moonrecur.execute([
    "expand", "--start", "2026-08-03", "--rule", "FREQ=WEEKLY;COUNT=3", "--from",
    "2026-08-01", "--through", "2026-08-31", "--rdate", "2026-08-05", "--rdate",
    "2026-08-05", "--exdate", "2026-08-10",
  ])
  assert_eq(result.exit_code, 0)
  assert_eq(result.output, "occurrences: 3\n2026-08-03\n2026-08-05\n2026-08-17")
}

///|
test "CLI rejects malformed exception dates" {
  let result = @moonrecur.execute([
    "expand", "--start", "2026-08-03", "--rule", "FREQ=WEEKLY;COUNT=3", "--from",
    "2026-08-01", "--through", "2026-08-31", "--exdate", "not-a-date",
  ])
  assert_eq(result.exit_code, 2)
  assert_true(result.output.contains("date.syntax"))
}

///|
test "CLI validates numeric limits windows and help" {
  assert_true(@moonrecur.execute([]).output.contains("USAGE:"))
  let text_limit = @moonrecur.execute([
    "expand", "--rule", "FREQ=DAILY", "--start", "2026-01-01", "--from", "2026-01-01",
    "--through", "2026-01-02", "--limit", "many",
  ])
  assert_eq(text_limit.exit_code, 2)
  assert_true(text_limit.output.contains("--limit must be an integer"))
  let reversed = @moonrecur.execute([
    "expand", "--rule", "FREQ=DAILY", "--start", "2026-01-01", "--from", "2026-01-02",
    "--through", "2026-01-01",
  ])
  assert_eq(reversed.exit_code, 2)
  assert_true(reversed.output.contains("expand.window.order"))
}

///|
test "CLI explain renders COUNT and UNTIL termination" {
  assert_true(
    @moonrecur.execute(["explain", "--rule", "FREQ=DAILY;COUNT=2"]).output.contains(
      "termination: count=2",
    ),
  )
  assert_true(
    @moonrecur.execute(["explain", "--rule", "FREQ=YEARLY;UNTIL=2030-01-01"]).output.contains(
      "termination: until=2030-01-01",
    ),
  )
}

///|
test "CLI reports input diagnostics and usage errors" {
  let invalid = @moonrecur.execute([
    "validate", "--rule", "FREQ=MONTHLY;BYMONTH=13",
  ])
  assert_eq(invalid.exit_code, 2)
  assert_true(invalid.output.contains("rule.value.range"))
  let missing = @moonrecur.execute(["expand", "--start", "2026-01-01"])
  assert_eq(missing.exit_code, 2)
  assert_eq(missing.output, "missing required option --rule")
  let unknown = @moonrecur.execute(["launch"])
  assert_eq(unknown.exit_code, 2)
  assert_true(unknown.output.contains("unknown command: launch"))
}
