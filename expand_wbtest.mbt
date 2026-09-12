///|
test "sparse daily scan visits 37 rather than 366001 candidates" {
  let start = Date::parse("2000-01-01").unwrap()
  let rule = Rule::parse("FREQ=DAILY;INTERVAL=10000").unwrap()
  let end = start.add_days(366000).unwrap()
  let mut current = start
  let mut visited = 0
  while !current.is_after(end) {
    visited += 1
    current = next_active_date(current, rule).unwrap()
  }
  assert_eq(visited, 37)
  let window = ExpansionWindow::make(start, end, 100).unwrap()
  assert_eq(expand(start, rule, window).unwrap().length(), visited)
}

///|
test "period skipping respects week anchors month ends and upper year boundary" {
  assert_eq(
    next_active_date(
      Date::parse("2024-01-07").unwrap(),
      Rule::parse("FREQ=WEEKLY;INTERVAL=3").unwrap(),
    )
    .unwrap()
    .to_iso(),
    "2024-01-22",
  )
  assert_eq(
    next_active_date(
      Date::parse("2024-01-31").unwrap(),
      Rule::parse("FREQ=MONTHLY;INTERVAL=2").unwrap(),
    )
    .unwrap()
    .to_iso(),
    "2024-03-01",
  )
  assert_eq(
    next_active_date(
      Date::parse("2024-12-31").unwrap(),
      Rule::parse("FREQ=YEARLY;INTERVAL=3").unwrap(),
    )
    .unwrap()
    .to_iso(),
    "2027-01-01",
  )
  assert_true(
    next_active_date(
      Date::parse("9999-12-31").unwrap(),
      Rule::parse("FREQ=YEARLY").unwrap(),
    )
    is Err(_),
  )
}
