///|
/// A validated date in the proleptic Gregorian calendar.
pub(all) struct Date {
  year : Int
  month : Int
  day : Int
} derive(Eq, Hash, @debug.Debug)

///|
/// Days of the week, ordered from Monday through Sunday.
pub(all) enum Weekday {
  Monday
  Tuesday
  Wednesday
  Thursday
  Friday
  Saturday
  Sunday
} derive(Eq, Hash, @debug.Debug)

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
pub fn Date::make(
  year : Int,
  month : Int,
  day : Int,
) -> Result[Date, Diagnostic] {
  if year < 1 || year > 9999 {
    return Err(
      Diagnostic::new(
        "date.year.range",
        "year",
        "year is outside the supported range",
        "1..9999",
        year.to_string(),
      ),
    )
  }
  if month < 1 || month > 12 {
    return Err(
      Diagnostic::new(
        "date.month.range",
        "month",
        "month is outside the Gregorian range",
        "1..12",
        month.to_string(),
      ),
    )
  }
  let last = days_in_month(year, month)
  if day < 1 || day > last {
    return Err(
      Diagnostic::new(
        "date.day.range",
        "day",
        "day does not exist in this month",
        "1.." + last.to_string(),
        day.to_string(),
      ),
    )
  }
  Ok({ year, month, day, })
}

///|
fn parse_fixed_digits(
  value : StringView,
  field : String,
) -> Result[Int, Diagnostic] {
  let mut result = 0
  for char in value {
    if char < '0' || char > '9' {
      return Err(
        Diagnostic::new(
          "date.syntax",
          field,
          "date component must contain only digits",
          "decimal digits",
          value.to_owned(),
        ),
      )
    }
    result = result * 10 + char.to_int() - '0'.to_int()
  }
  Ok(result)
}

///|
/// Parse an ISO 8601 calendar date in `YYYY-MM-DD` form.
pub fn Date::parse(value : String) -> Result[Date, Diagnostic] {
  if value.length() != 10 || value[4] != '-' || value[7] != '-' {
    return Err(
      Diagnostic::new(
        "date.syntax", "date", "date must use the ISO calendar form", "YYYY-MM-DD",
        value,
      ),
    )
  }
  let year = match parse_fixed_digits(value[:4], "year") {
    Ok(number) => number
    Err(error) => return Err(error)
  }
  let month = match parse_fixed_digits(value[5:7], "month") {
    Ok(number) => number
    Err(error) => return Err(error)
  }
  let day = match parse_fixed_digits(value[8:10], "day") {
    Ok(number) => number
    Err(error) => return Err(error)
  }
  Date::make(year, month, day)
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
pub fn Date::compare(self : Date, other : Date) -> Int {
  if self.year != other.year {
    self.year - other.year
  } else if self.month != other.month {
    self.month - other.month
  } else {
    self.day - other.day
  }
}

///|
pub fn Date::is_before(self : Date, other : Date) -> Bool {
  self.compare(other) < 0
}

///|
pub fn Date::is_after(self : Date, other : Date) -> Bool {
  self.compare(other) > 0
}

///|
/// Number of days since 1970-01-01. Valid for the complete supported year range.
pub fn Date::epoch_day(self : Date) -> Int64 {
  let mut year = self.year
  let month = self.month
  year = year - (if month <= 2 { 1 } else { 0 })
  let era = year / 400
  let year_of_era = year - era * 400
  let shifted_month = month + (if month > 2 { -3 } else { 9 })
  let day_of_year = (153 * shifted_month + 2) / 5 + self.day - 1
  let day_of_era = year_of_era * 365 +
    year_of_era / 4 -
    year_of_era / 100 +
    day_of_year
  (era * 146097 + day_of_era - 719468).to_int64()
}

///|
fn date_from_epoch_day(value : Int64) -> Date {
  let shifted = value + 719468L
  let era = shifted / 146097L
  let day_of_era = shifted - era * 146097L
  let year_of_era = (
      day_of_era -
      day_of_era / 1460L +
      day_of_era / 36524L -
      day_of_era / 146096L
    ) /
    365L
  let year = year_of_era + era * 400L
  let day_of_year = day_of_era -
    (365L * year_of_era + year_of_era / 4L - year_of_era / 100L)
  let month_prime = (5L * day_of_year + 2L) / 153L
  let day = day_of_year - (153L * month_prime + 2L) / 5L + 1L
  let month = month_prime + (if month_prime < 10L { 3L } else { -9L })
  let adjusted_year = year + (if month <= 2L { 1L } else { 0L })
  { year: adjusted_year.to_int(), month: month.to_int(), day: day.to_int(), }
}

///|
pub fn Date::add_days(self : Date, amount : Int) -> Result[Date, Diagnostic] {
  let candidate = date_from_epoch_day(self.epoch_day() + amount.to_int64())
  if candidate.year < 1 || candidate.year > 9999 {
    Err(
      Diagnostic::new(
        "date.overflow",
        "date",
        "date arithmetic left the supported range",
        "year 1..9999",
        candidate.year.to_string(),
      ),
    )
  } else {
    Ok(candidate)
  }
}

///|
/// Add calendar months, clamping the day to the final valid day of the target month.
pub fn Date::add_months(self : Date, amount : Int) -> Result[Date, Diagnostic] {
  let index = self.year * 12 + self.month - 1 + amount
  if index < 12 || index >= 120000 {
    return Err(
      Diagnostic::new(
        "date.overflow",
        "date",
        "month arithmetic left the supported range",
        "year 1..9999",
        index.to_string(),
      ),
    )
  }
  let year = index / 12
  let month = index % 12 + 1
  let day = self.day.min(days_in_month(year, month))
  Ok({ year, month, day, })
}

///|
pub fn Date::weekday(self : Date) -> Weekday {
  let index = ((self.epoch_day() + 3L) % 7L + 7L) % 7L
  match index.to_int() {
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

///|
pub fn Weekday::parse(value : String) -> Result[Weekday, Diagnostic] {
  match value {
    "MO" => Ok(Monday)
    "TU" => Ok(Tuesday)
    "WE" => Ok(Wednesday)
    "TH" => Ok(Thursday)
    "FR" => Ok(Friday)
    "SA" => Ok(Saturday)
    "SU" => Ok(Sunday)
    _ =>
      Err(
        Diagnostic::new(
          "weekday.invalid", "BYDAY", "unknown weekday token", "MO,TU,WE,TH,FR,SA,SU",
          value,
        ),
      )
  }
}
