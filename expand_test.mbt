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

///|
test "positive month-day and month selectors filter candidates" {
  let rule = @moonrecur.Rule::parse(
    "FREQ=MONTHLY;BYMONTHDAY=15;BYMONTH=2,3;COUNT=2",
  ).unwrap()
  let values = @moonrecur.expand(
    date("2026-01-01"),
    rule,
    window("2026-01-01", "2027-12-31", 10),
  ).unwrap()
  assert_eq(@moonrecur.dates_to_lines(values), "2026-02-15\n2026-03-15")
}

///|
test "UNTIL beyond the window preserves the caller bound" {
  let rule = @moonrecur.Rule::parse("FREQ=DAILY;UNTIL=2026-02-01").unwrap()
  let values = @moonrecur.expand(
    date("2026-01-01"),
    rule,
    window("2026-01-01", "2026-01-03", 10),
  ).unwrap()
  assert_eq(
    @moonrecur.dates_to_lines(values),
    "2026-01-01\n2026-01-02\n2026-01-03",
  )
}

///|
test "result limit stops otherwise unbounded rules" {
  let rule = @moonrecur.Rule::parse("FREQ=DAILY").unwrap()
  let values = @moonrecur.expand(
    date("2026-01-01"),
    rule,
    window("2026-01-01", "2026-12-31", 2),
  ).unwrap()
  assert_eq(@moonrecur.dates_to_lines(values), "2026-01-01\n2026-01-02")
}

///|
test "yearly BYMONTH expands selected months with inherited day" {
  let rule = @moonrecur.Rule::parse("FREQ=YEARLY;BYMONTH=2,6;COUNT=4").unwrap()
  let values = @moonrecur.expand(
    date("2024-01-15"),
    rule,
    window("2024-01-01", "2025-12-31", 10),
  ).unwrap()
  assert_eq(
    @moonrecur.dates_to_lines(values),
    "2024-02-15\n2024-06-15\n2025-02-15\n2025-06-15",
  )
}

///|
test "yearly BYMONTHDAY without BYMONTH expands across the year" {
  let rule = @moonrecur.Rule::parse("FREQ=YEARLY;BYMONTHDAY=-1;COUNT=3").unwrap()
  let values = @moonrecur.expand(
    date("2024-01-01"),
    rule,
    window("2024-01-01", "2024-12-31", 10),
  ).unwrap()
  assert_eq(
    @moonrecur.dates_to_lines(values),
    "2024-01-31\n2024-02-29\n2024-03-31",
  )
}

///|
test "yearly BYDAY does not inherit DTSTART month" {
  let rule = @moonrecur.Rule::parse("FREQ=YEARLY;BYDAY=MO;COUNT=3").unwrap()
  let values = @moonrecur.expand(
    date("2024-01-29"),
    rule,
    window("2024-01-01", "2024-12-31", 10),
  ).unwrap()
  assert_eq(
    @moonrecur.dates_to_lines(values),
    "2024-01-29\n2024-02-05\n2024-02-12",
  )
}

///|
test "exclusions are applied before the result limit without resetting COUNT" {
  let start = date("2026-01-01")
  let w = window("2026-01-01", "2026-01-10", 2)
  let removed = [start, date("2026-01-02")]
  let values = @moonrecur.expand_set(
    start,
    @moonrecur.Rule::parse("FREQ=DAILY;COUNT=5").unwrap(),
    w,
    [],
    removed,
  ).unwrap()
  assert_eq(@moonrecur.dates_to_lines(values), "2026-01-03\n2026-01-04")
  let exhausted = @moonrecur.expand_set(
    start,
    @moonrecur.Rule::parse("FREQ=DAILY;COUNT=2").unwrap(),
    w,
    [],
    removed,
  ).unwrap()
  assert_true(exhausted.is_empty())
}

///|
test "RDATE union is sorted deduplicated and excluded before truncation" {
  let values = @moonrecur.expand_set(
    date("2026-01-05"),
    @moonrecur.Rule::parse("FREQ=DAILY;COUNT=5").unwrap(),
    window("2026-01-01", "2026-01-31", 3),
    [
      date("2026-01-03"),
      date("2026-01-01"),
      date("2026-01-03"),
      date("2026-01-05"),
    ],
    [date("2026-01-01"), date("2026-01-05")],
  ).unwrap()
  assert_eq(
    @moonrecur.dates_to_lines(values),
    "2026-01-03\n2026-01-06\n2026-01-07",
  )
}

///|
test "public aggregate inputs are revalidated before arithmetic" {
  let good = @moonrecur.Rule::parse("FREQ=DAILY").unwrap()
  let bad : @moonrecur.Rule = { ..good, interval: 0, }
  assert_true(
    @moonrecur.expand(
      date("2026-01-01"),
      bad,
      window("2026-01-01", "2026-01-10", 10),
    )
    is Err(_),
  )
  let invalid_window : @moonrecur.ExpansionWindow = {
    from: date("2026-01-01"),
    through: date("2026-01-10"),
    limit: 0,
  }
  assert_true(
    @moonrecur.expand(date("2026-01-01"), good, invalid_window) is Err(_),
  )
  let invalid_date : @moonrecur.Date = { year: 2026, month: 2, day: 30, }
  assert_true(
    @moonrecur.expand(
      invalid_date,
      good,
      window("2026-01-01", "2026-12-31", 10),
    )
    is Err(_),
  )
  assert_true(
    @moonrecur.expand_set(
      date("2026-01-01"),
      good,
      window("2026-01-01", "2026-12-31", 10),
      [invalid_date],
      [],
    )
    is Err(_),
  )
}

///|
test "mutated selector arrays cannot bypass rule validation" {
  let rule = @moonrecur.Rule::parse("FREQ=YEARLY;BYMONTH=1").unwrap()
  rule.by_month.push(13)
  assert_true(
    @moonrecur.expand(
      date("2026-01-01"),
      rule,
      window("2026-01-01", "2026-12-31", 10),
    )
    is Err(_),
  )
}
