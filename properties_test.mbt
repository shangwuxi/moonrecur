///|
test "complete Gregorian 400-year cycle agrees with independent month lengths" {
  let mut expected = @moonrecur.Date::make(2000, 1, 1).unwrap()
  let mut checked = 0
  for year in 2000..<2400 {
    let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    for month in 1..<13 {
      let days = match month {
        2 => if leap { 29 } else { 28 }
        4 | 6 | 9 | 11 => 30
        _ => 31
      }
      for day in 1..<(days + 1) {
        assert_eq(expected.year, year)
        assert_eq(expected.month, month)
        assert_eq(expected.day, day)
        assert_eq(@moonrecur.Date::parse(expected.to_iso()).unwrap(), expected)
        expected = expected.add_days(1).unwrap()
        checked += 1
      }
    }
  }
  assert_eq(checked, 146097)
  assert_eq(expected.to_iso(), "2400-01-01")
}

///|
test "200 generated schedules agree with an independent daily occupancy model" {
  let origin = @moonrecur.Date::make(2024, 1, 1).unwrap()
  for seed in 0..<200 {
    let busy : Array[@moonrecur.BusySpan] = []
    let occupied = Array::make(90, false)
    for index in 0..<20 {
      let from = (seed * 13 + index * 31) % 120 - 15
      let duration = (seed + index * 7) % 12
      busy.push(
        @moonrecur.BusySpan::make(
          index.to_string(),
          origin.add_days(from).unwrap(),
          origin.add_days(from + duration).unwrap(),
        ).unwrap(),
      )
      for day in 0..<90 {
        if day >= from && day <= from + duration {
          occupied[day] = true
        }
      }
    }
    let free = @moonrecur.find_free(origin, origin.add_days(89).unwrap(), busy).unwrap()
    let merged = @moonrecur.merge_busy(busy)
    for day in 0..<90 {
      let date = origin.add_days(day).unwrap()
      let available = free.any(fn(span) {
        !date.is_before(span.start) && !date.is_after(span.end)
      })
      let covered = merged.any(fn(span) {
        !date.is_before(span.start) && !date.is_after(span.end)
      })
      assert_eq(available, !occupied[day])
      assert_eq(covered, occupied[day])
    }
    for i in 1..<free.length() {
      assert_true(free[i].start.is_after(free[i - 1].end))
    }
  }
}

///|
test "equal busy spans retain caller label order without mutating input" {
  let date = @moonrecur.Date::make(2024, 1, 1).unwrap()
  let spans = [
    @moonrecur.BusySpan::make("z", date, date).unwrap(),
    @moonrecur.BusySpan::make("a", date, date).unwrap(),
  ]
  assert_eq(@moonrecur.merge_busy(spans)[0].label, "z+a")
  assert_eq(spans[0].label, "z")
  assert_eq(spans.length(), 2)
}
