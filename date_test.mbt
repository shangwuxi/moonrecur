///|
test "parse and format ISO dates" {
  let date = @moonrecur.Date::parse("2024-02-29").unwrap()
  assert_eq(date.to_iso(), "2024-02-29")
  assert_eq(date.year, 2024)
  assert_eq(date.month, 2)
  assert_eq(date.day, 29)
}

///|
test "reject malformed and nonexistent dates with stable codes" {
  let syntax = @moonrecur.Date::parse("2024/02/29")
  guard syntax is Err(syntax_error) else { fail("expected syntax error") }
  assert_eq(syntax_error.code(), "date.syntax")
  let invalid = @moonrecur.Date::parse("2023-02-29")
  guard invalid is Err(invalid_error) else { fail("expected range error") }
  assert_eq(invalid_error.code(), "date.day.range")
  assert_eq(invalid_error.field(), "day")
}

///|
test "Gregorian leap year rules include century exception" {
  assert_true(@moonrecur.is_leap_year(2000))
  assert_false(@moonrecur.is_leap_year(1900))
  assert_true(@moonrecur.is_leap_year(2024))
  assert_false(@moonrecur.is_leap_year(2023))
}

///|
test "day arithmetic crosses leap day and supports negative offsets" {
  let leap = @moonrecur.Date::parse("2024-02-28").unwrap()
  assert_eq(leap.add_days(1).unwrap().to_iso(), "2024-02-29")
  assert_eq(leap.add_days(2).unwrap().to_iso(), "2024-03-01")
  let new_year = @moonrecur.Date::parse("2024-01-01").unwrap()
  assert_eq(new_year.add_days(-1).unwrap().to_iso(), "2023-12-31")
}

///|
test "month arithmetic clamps to valid month end" {
  let january = @moonrecur.Date::parse("2024-01-31").unwrap()
  assert_eq(january.add_months(1).unwrap().to_iso(), "2024-02-29")
  assert_eq(january.add_months(2).unwrap().to_iso(), "2024-03-31")
  let march = @moonrecur.Date::parse("2023-03-31").unwrap()
  assert_eq(march.add_months(-1).unwrap().to_iso(), "2023-02-28")
}

///|
test "weekday matches known dates across epoch" {
  assert_eq(
    @moonrecur.Date::parse("1970-01-01").unwrap().weekday().short_name(),
    "TH",
  )
  assert_eq(
    @moonrecur.Date::parse("2024-02-29").unwrap().weekday().short_name(),
    "TH",
  )
  assert_eq(
    @moonrecur.Date::parse("1969-12-29").unwrap().weekday().short_name(),
    "MO",
  )
}

///|
test "date arithmetic rejects supported-range overflow" {
  let first = @moonrecur.Date::parse("0001-01-01").unwrap()
  guard first.add_days(-1) is Err(error) else { fail("expected underflow") }
  assert_eq(error.code(), "date.overflow")
  let last = @moonrecur.Date::parse("9999-12-31").unwrap()
  guard last.add_days(1) is Err(error) else { fail("expected overflow") }
  assert_eq(error.code(), "date.overflow")
}

///|
test "date constructors reject component bounds and non-digits" {
  assert_eq(
    @moonrecur.Date::make(0, 1, 1).unwrap_err().code(),
    "date.year.range",
  )
  assert_eq(
    @moonrecur.Date::make(10000, 1, 1).unwrap_err().code(),
    "date.year.range",
  )
  assert_eq(
    @moonrecur.Date::make(2026, 0, 1).unwrap_err().code(),
    "date.month.range",
  )
  assert_eq(
    @moonrecur.Date::make(2026, 13, 1).unwrap_err().code(),
    "date.month.range",
  )
  assert_eq(
    @moonrecur.Date::parse("20x6-08-13").unwrap_err().code(),
    "date.syntax",
  )
  assert_eq(
    @moonrecur.Date::parse("2026-0x-13").unwrap_err().code(),
    "date.syntax",
  )
  assert_eq(
    @moonrecur.Date::parse("2026-08-1x").unwrap_err().code(),
    "date.syntax",
  )
}

///|
test "month arithmetic rejects year overflow" {
  assert_eq(
    @moonrecur.Date::parse("0001-01-01")
    .unwrap()
    .add_months(-1)
    .unwrap_err()
    .code(),
    "date.overflow",
  )
  assert_eq(
    @moonrecur.Date::parse("9999-12-31")
    .unwrap()
    .add_months(1)
    .unwrap_err()
    .code(),
    "date.overflow",
  )
}

///|
test "all weekday tokens parse and format" {
  for token in ["MO", "TU", "WE", "TH", "FR", "SA", "SU"] {
    assert_eq(@moonrecur.Weekday::parse(token).unwrap().short_name(), token)
  }
  assert_eq(
    @moonrecur.Weekday::parse("XX").unwrap_err().code(),
    "weekday.invalid",
  )
}
