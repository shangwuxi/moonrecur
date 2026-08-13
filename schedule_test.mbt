///|
test "detect pairwise overlaps including boundary day" {
  let spans = [
    @moonrecur.BusySpan::make("release", date("2026-08-10"), date("2026-08-12")).unwrap(),
    @moonrecur.BusySpan::make("review", date("2026-08-12"), date("2026-08-13")).unwrap(),
    @moonrecur.BusySpan::make("travel", date("2026-08-20"), date("2026-08-21")).unwrap(),
  ]
  let conflicts = @moonrecur.find_conflicts(spans)
  assert_eq(conflicts.length(), 1)
  assert_eq(conflicts[0].to_text(), "release <> review:2026-08-12..2026-08-12")
}

///|
test "merge overlapping and adjacent busy spans" {
  let merged = @moonrecur.merge_busy([
    @moonrecur.BusySpan::make("c", date("2026-08-15"), date("2026-08-15")).unwrap(),
    @moonrecur.BusySpan::make("a", date("2026-08-10"), date("2026-08-12")).unwrap(),
    @moonrecur.BusySpan::make("b", date("2026-08-13"), date("2026-08-14")).unwrap(),
  ])
  assert_eq(merged.length(), 1)
  assert_eq(merged[0].start.to_iso(), "2026-08-10")
  assert_eq(merged[0].end.to_iso(), "2026-08-15")
}

///|
test "find free ranges with clipped out-of-window busy spans" {
  let free = @moonrecur.find_free(date("2026-08-01"), date("2026-08-10"), [
    @moonrecur.BusySpan::make("before", date("2026-07-20"), date("2026-08-02")).unwrap(),
    @moonrecur.BusySpan::make("middle", date("2026-08-05"), date("2026-08-06")).unwrap(),
    @moonrecur.BusySpan::make("after", date("2026-08-10"), date("2026-08-20")).unwrap(),
  ]).unwrap()
  assert_eq(free.length(), 2)
  assert_eq(free[0].to_text(), "2026-08-03..2026-08-04")
  assert_eq(free[1].to_text(), "2026-08-07..2026-08-09")
}

///|
test "convert recurrence dates to duration-bearing spans" {
  let values = @moonrecur.occurrences_to_busy(
    "sprint",
    [date("2026-08-03"), date("2026-08-17")],
    5,
  ).unwrap()
  assert_eq(values[0].to_text(), "sprint:2026-08-03..2026-08-07")
  assert_eq(values[1].to_text(), "sprint:2026-08-17..2026-08-21")
}

///|
test "reject invalid schedule spans and durations" {
  guard @moonrecur.BusySpan::make("", date("2026-08-01"), date("2026-08-01"))
    is Err(label) else {
    fail("expected empty label")
  }
  assert_eq(label.code(), "schedule.label.empty")
  guard @moonrecur.BusySpan::make("bad", date("2026-08-02"), date("2026-08-01"))
    is Err(order) else {
    fail("expected order error")
  }
  assert_eq(order.code(), "schedule.span.order")
  guard @moonrecur.occurrences_to_busy("x", [date("2026-08-01")], 0)
    is Err(duration) else {
    fail("expected duration error")
  }
  assert_eq(duration.code(), "schedule.duration.range")
}

///|
test "free ranges include the trailing window and reject reversed windows" {
  let free = @moonrecur.find_free(date("2026-08-01"), date("2026-08-10"), [
    @moonrecur.BusySpan::make("opening", date("2026-08-01"), date("2026-08-02")).unwrap(),
  ]).unwrap()
  assert_eq(free.length(), 1)
  assert_eq(free[0].to_text(), "2026-08-03..2026-08-10")
  assert_eq(
    @moonrecur.find_free(date("2026-08-10"), date("2026-08-01"), [])
    .unwrap_err()
    .code(),
    "schedule.window.order",
  )
}
