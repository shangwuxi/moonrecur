///|
test "Gregorian leap-year rules" {
  assert_true(@moonrecur.is_leap_year(2000))
  assert_false(@moonrecur.is_leap_year(1900))
  assert_true(@moonrecur.is_leap_year(2024))
  assert_false(@moonrecur.is_leap_year(2023))
}

///|
test "date parsing validates shape and calendar ranges" {
  assert_eq(
    @moonrecur.Date::parse("2024-02-29").unwrap().to_iso(),
    "2024-02-29",
  )
  let invalid_day = @moonrecur.Date::parse("2023-02-29").unwrap_err()
  assert_eq(invalid_day.code, "date.day.range")
  assert_eq(invalid_day.field, "day")
  let invalid_shape = @moonrecur.Date::parse("24-02-29").unwrap_err()
  assert_eq(invalid_shape.code, "date.syntax")
  assert_eq(invalid_shape.field, "date")
}

///|
test "ordinal conversion round trips boundary dates" {
  let samples = [
    "0001-01-01", "1600-02-29", "1900-03-01", "2000-02-29", "9999-12-31",
  ]
  for sample in samples {
    let date = @moonrecur.Date::parse(sample).unwrap()
    assert_eq(
      @moonrecur.Date::from_ordinal(date.ordinal()).unwrap().to_iso(),
      sample,
    )
  }
}

///|
test "day arithmetic crosses leap and year boundaries" {
  let leap = @moonrecur.Date::parse("2024-02-28").unwrap()
  assert_eq(leap.add_days(1).unwrap().to_iso(), "2024-02-29")
  assert_eq(leap.add_days(2).unwrap().to_iso(), "2024-03-01")
  let year_end = @moonrecur.Date::parse("2023-12-31").unwrap()
  assert_eq(year_end.add_days(1).unwrap().to_iso(), "2024-01-01")
}

///|
test "month arithmetic clamps at month end" {
  let date = @moonrecur.Date::parse("2024-01-31").unwrap()
  assert_eq(date.add_months(1).unwrap().to_iso(), "2024-02-29")
  assert_eq(date.add_months(-1).unwrap().to_iso(), "2023-12-31")
}

///|
test "weekday uses ISO Monday origin" {
  assert_eq(
    @moonrecur.Date::parse("0001-01-01").unwrap().weekday().short_name(),
    "MO",
  )
  assert_eq(
    @moonrecur.Date::parse("2026-08-13").unwrap().weekday().short_name(),
    "TH",
  )
}
