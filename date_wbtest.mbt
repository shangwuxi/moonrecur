///|
test "epoch conversion round trips representative range" {
  for
    value in [
      "0001-01-01", "1582-10-15", "1969-12-31", "1970-01-01", "2000-02-29", "9999-12-31",
    ] {
    let date = Date::parse(value).unwrap()
    assert_eq(date_from_epoch_day(date.epoch_day()).to_iso(), value)
  }
}
