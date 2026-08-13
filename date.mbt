///|
/// A proleptic Gregorian civil date. Valid values use years 1 through 9999.
pub(all) struct Date {
  year : Int
  month : Int
  day : Int
} derive(Eq, @debug.Debug)

///|
/// Stable machine-readable diagnostic returned by public operations.
pub(all) struct Diagnostic {
  code : String
  field : String
  message : String
} derive(Eq, @debug.Debug)

///|
fn diagnostic(code : String, field : String, message : String) -> Diagnostic {
  { code, field, message }
}

///|
/// Weekdays use ISO order, Monday through Sunday.
pub(all) enum Weekday {
  Monday
  Tuesday
  Wednesday
  Thursday
  Friday
  Saturday
  Sunday
} derive(Eq, Compare, @debug.Debug)

///|
pub fn is_leap_year(year : Int) -> Bool {
  year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

///|
pub fn days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if is_leap_year(year) { 29 } else { 28 }
    _ => 0
  }
}

///|
pub fn Date::new(
  year : Int,
  month : Int,
  day : Int,
) -> Result[Date, Diagnostic] {
  if year < 1 || year > 9999 {
    return Err(diagnostic("date.year.range", "year", "year must be in 1..9999"))
  }
  if month < 1 || month > 12 {
    return Err(
      diagnostic("date.month.range", "month", "month must be in 1..12"),
    )
  }
  let maximum = days_in_month(year, month)
  if day < 1 || day > maximum {
    return Err(
      diagnostic("date.day.range", "day", "day is outside the selected month"),
    )
  }
  Ok({ year, month, day })
}

///|
pub fn Date::compare(self : Date, other : Date) -> Int {
  if self.year != other.year {
    self.year.compare(other.year)
  } else if self.month != other.month {
    self.month.compare(other.month)
  } else {
    self.day.compare(other.day)
  }
}

///|
fn two_digits(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn four_digits(value : Int) -> String {
  if value < 10 {
    "000" + value.to_string()
  } else if value < 100 {
    "00" + value.to_string()
  } else if value < 1000 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
pub fn Date::to_iso(self : Date) -> String {
  four_digits(self.year) +
  "-" +
  two_digits(self.month) +
  "-" +
  two_digits(self.day)
}

///|
fn parse_fixed_int(
  text : StringView,
  field : String,
) -> Result[Int, Diagnostic] {
  Ok(@string.parse_int(text)) catch {
    _ => Err(diagnostic("date.syntax", field, "expected decimal digits"))
  }
}

///|
pub fn Date::parse(text : String) -> Result[Date, Diagnostic] {
  let parts = text.split("-").to_array()
  if parts.length() != 3 ||
    parts[0].length() != 4 ||
    parts[1].length() != 2 ||
    parts[2].length() != 2 {
    return Err(diagnostic("date.syntax", "date", "expected YYYY-MM-DD"))
  }
  match
    (
      parse_fixed_int(parts[0], "year"),
      parse_fixed_int(parts[1], "month"),
      parse_fixed_int(parts[2], "day"),
    ) {
    (Ok(year), Ok(month), Ok(day)) => Date::new(year, month, day)
    (Err(error), _, _) | (_, Err(error), _) | (_, _, Err(error)) => Err(error)
  }
}

///|
fn days_before_year(year : Int) -> Int {
  let y = year - 1
  y * 365 + y / 4 - y / 100 + y / 400
}

///|
fn days_before_month(year : Int, month : Int) -> Int {
  let cumulative = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
  let base = cumulative[month - 1]
  if month > 2 && is_leap_year(year) {
    base + 1
  } else {
    base
  }
}

///|
/// Returns a zero-based day number where 0001-01-01 is zero.
pub fn Date::ordinal(self : Date) -> Int {
  days_before_year(self.year) +
  days_before_month(self.year, self.month) +
  self.day -
  1
}

///|
pub fn Date::from_ordinal(value : Int) -> Result[Date, Diagnostic] {
  let maximum = days_before_year(10000) - 1
  if value < 0 || value > maximum {
    return Err(
      diagnostic(
        "date.ordinal.range", "ordinal", "ordinal is outside years 1..9999",
      ),
    )
  }
  let mut low = 1
  let mut high = 10000
  while low + 1 < high {
    let middle = (low + high) / 2
    if days_before_year(middle) <= value {
      low = middle
    } else {
      high = middle
    }
  }
  let year = low
  let day_of_year = value - days_before_year(year)
  let mut month = 1
  while month < 12 && days_before_month(year, month + 1) <= day_of_year {
    month = month + 1
  }
  Date::new(year, month, day_of_year - days_before_month(year, month) + 1)
}

///|
pub fn Date::add_days(self : Date, amount : Int) -> Result[Date, Diagnostic] {
  Date::from_ordinal(self.ordinal() + amount)
}

///|
/// Shifts by calendar months, clamping the day to the target month's last day.
pub fn Date::add_months(self : Date, amount : Int) -> Result[Date, Diagnostic] {
  let absolute = self.year * 12 + self.month - 1 + amount
  if absolute < 12 || absolute >= 10000 * 12 {
    return Err(
      diagnostic(
        "date.month_shift.range", "amount", "month shift leaves years 1..9999",
      ),
    )
  }
  let year = absolute / 12
  let month = absolute % 12 + 1
  let day = self.day.min(days_in_month(year, month))
  Date::new(year, month, day)
}

///|
pub fn Date::weekday(self : Date) -> Weekday {
  match self.ordinal() % 7 {
    0 => Monday
    1 => Tuesday
    2 => Wednesday
    3 => Thursday
    4 => Friday
    5 => Saturday
    _ => Sunday
  }
}

///|
pub fn Weekday::short_name(self : Weekday) -> String {
  match self {
    Monday => "MO"
    Tuesday => "TU"
    Wednesday => "WE"
    Thursday => "TH"
    Friday => "FR"
    Saturday => "SA"
    Sunday => "SU"
  }
}
