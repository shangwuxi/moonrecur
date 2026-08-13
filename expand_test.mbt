///|
fn date(value : String) -> @moonrecur.Date {
  @moonrecur.Date::parse(value).unwrap()
}

///|
fn window(
  from : String,
  through : String,
  limit : Int,
) -> @moonrecur.ExpansionWindow {
  @moonrecur.ExpansionWindow::make(date(from), date(through), limit).unwrap()
}

///|
test "expand weekly weekdays with interval" {
  let rule = @moonrecur.Rule::parse(
    "FREQ=WEEKLY;INTERVAL=2;COUNT=6;BYDAY=MO,WE",
  ).unwrap()
  let values = @moonrecur.expand(
    date("2026-08-03"),
    rule,
    window("2026-08-01", "2026-09-30", 20),
  ).unwrap()
  assert_eq(
    @moonrecur.dates_to_lines(values),
    "2026-08-03\n2026-08-05\n2026-08-17\n2026-08-19\n2026-08-31\n2026-09-02",
  )
}

///|
test "monthly day skips months where date does not exist" {
  let rule = @moonrecur.Rule::parse("FREQ=MONTHLY;COUNT=4").unwrap()
  let values = @moonrecur.expand(
    date("2024-01-31"),
    rule,
    window("2024-01-01", "2024-07-31", 10),
  ).unwrap()
  assert_eq(
    @moonrecur.dates_to_lines(values),
    "2024-01-31\n2024-03-31\n2024-05-31\n2024-07-31",
  )
}

///|
test "negative month day selects each month end" {
  let rule = @moonrecur.Rule::parse("FREQ=MONTHLY;COUNT=4;BYMONTHDAY=-1").unwrap()
  let values = @moonrecur.expand(
    date("2024-01-31"),
    rule,
    window("2024-01-01", "2024-04-30", 10),
  ).unwrap()
  assert_eq(
    @moonrecur.dates_to_lines(values),
    "2024-01-31\n2024-02-29\n2024-03-31\n2024-04-30",
  )
}

///|
test "yearly leap day skips non-leap years" {
  let rule = @moonrecur.Rule::parse("FREQ=YEARLY;COUNT=3").unwrap()
  let values = @moonrecur.expand(
    date("2024-02-29"),
    rule,
    window("2024-01-01", "2033-01-01", 10),
  ).unwrap()
  assert_eq(
    @moonrecur.dates_to_lines(values),
    "2024-02-29\n2028-02-29\n2032-02-29",
  )
}

///|
test "window does not reset COUNT semantics" {
  let rule = @moonrecur.Rule::parse("FREQ=DAILY;COUNT=3").unwrap()
  let values = @moonrecur.expand(
    date("2026-01-01"),
    rule,
    window("2026-01-03", "2026-01-10", 10),
  ).unwrap()
  assert_eq(@moonrecur.dates_to_lines(values), "2026-01-03")
}

///|
test "UNTIL is inclusive and may not precede start" {
  let rule = @moonrecur.Rule::parse("FREQ=DAILY;UNTIL=2026-01-03").unwrap()
  let values = @moonrecur.expand(
    date("2026-01-01"),
    rule,
    window("2026-01-01", "2026-01-10", 10),
  ).unwrap()
  assert_eq(
    @moonrecur.dates_to_lines(values),
    "2026-01-01\n2026-01-02\n2026-01-03",
  )
  let invalid = @moonrecur.Rule::parse("FREQ=DAILY;UNTIL=2025-12-31").unwrap()
  guard @moonrecur.expand(
      date("2026-01-01"),
      invalid,
      window("2026-01-01", "2026-01-10", 10),
    )
    is Err(error) else {
    fail("expected invalid UNTIL")
  }
  assert_eq(error.code(), "expand.until.before_start")
}

///|
test "RDATE and EXDATE normalize a schedule set" {
  let rule = @moonrecur.Rule::parse("FREQ=WEEKLY;COUNT=3").unwrap()
  let values = @moonrecur.expand_set(
    date("2026-08-03"),
    rule,
    window("2026-08-01", "2026-08-31", 10),
    [date("2026-08-05"), date("2026-08-05")],
    [date("2026-08-10")],
  ).unwrap()
  assert_eq(
    @moonrecur.dates_to_lines(values),
    "2026-08-03\n2026-08-05\n2026-08-17",
  )
}

///|
test "reject reversed, excessive and invalid limits" {
  guard @moonrecur.ExpansionWindow::make(
      date("2026-02-01"),
      date("2026-01-01"),
      10,
    )
    is Err(order) else {
    fail("expected order error")
  }
  assert_eq(order.code(), "expand.window.order")
  guard @moonrecur.ExpansionWindow::make(
      date("2026-01-01"),
      date("2026-02-01"),
      0,
    )
    is Err(limit) else {
    fail("expected limit error")
  }
  assert_eq(limit.code(), "expand.limit.range")
}

///|
test "reject an expansion scan longer than one thousand years" {
  let rule = @moonrecur.Rule::parse("FREQ=YEARLY").unwrap()
  guard @moonrecur.expand(
      date("0001-01-01"),
      rule,
      window("0001-01-01", "2000-01-01", 10),
    )
    is Err(error) else {
    fail("expected scan limit error")
  }
  assert_eq(error.code(), "expand.scan.too_large")
}

///|
test "window before DTSTART returns an empty expansion" {
  let rule = @moonrecur.Rule::parse("FREQ=DAILY").unwrap()
  let values = @moonrecur.expand(
    date("2026-02-01"),
    rule,
    window("2026-01-01", "2026-01-31", 10),
  ).unwrap()
  assert_true(values.is_empty())
}
