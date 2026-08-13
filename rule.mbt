///|
/// Recurrence frequency supported by MoonRecur's date-only profile.
pub(all) enum Frequency {
  Daily
  Weekly
  Monthly
  Yearly
} derive(Eq, @debug.Debug)

///|
/// A validated date-only recurrence rule.
pub(all) struct Rule {
  frequency : Frequency
  interval : Int
  count : Int?
  until : Date?
  by_weekday : Array[Weekday]
  by_month_day : Array[Int]
  by_month : Array[Int]
} derive(Eq, @debug.Debug)

///|
pub fn Frequency::name(self : Frequency) -> String {
  match self {
    Daily => "DAILY"
    Weekly => "WEEKLY"
    Monthly => "MONTHLY"
    Yearly => "YEARLY"
  }
}

///|
fn parse_frequency(value : String) -> Result[Frequency, Diagnostic] {
  match value {
    "DAILY" => Ok(Daily)
    "WEEKLY" => Ok(Weekly)
    "MONTHLY" => Ok(Monthly)
    "YEARLY" => Ok(Yearly)
    "SECONDLY" | "MINUTELY" | "HOURLY" =>
      Err(
        Diagnostic::new(
          "rule.frequency.unsupported", "FREQ", "sub-daily frequencies are outside the date-only profile",
          "DAILY|WEEKLY|MONTHLY|YEARLY", value,
        ),
      )
    _ =>
      Err(
        Diagnostic::new(
          "rule.frequency.invalid", "FREQ", "unknown recurrence frequency", "DAILY|WEEKLY|MONTHLY|YEARLY",
          value,
        ),
      )
  }
}

///|
fn parse_integer(value : String, field : String) -> Result[Int, Diagnostic] {
  if value.is_empty() {
    return Err(
      Diagnostic::new(
        "rule.integer.syntax", field, "integer value is empty", "integer", value,
      ),
    )
  }
  let mut sign = 1
  let mut seen_digit = false
  let mut number = 0
  for index, char in value {
    if index == 0 && char == '-' {
      sign = -1
    } else if char >= '0' && char <= '9' {
      seen_digit = true
      number = number * 10 + char.to_int() - '0'.to_int()
    } else {
      return Err(
        Diagnostic::new(
          "rule.integer.syntax", field, "value is not a decimal integer", "integer",
          value,
        ),
      )
    }
  }
  if !seen_digit {
    Err(
      Diagnostic::new(
        "rule.integer.syntax", field, "value is not a decimal integer", "integer",
        value,
      ),
    )
  } else {
    Ok(number * sign)
  }
}

///|
fn insert_int_sorted(values : Array[Int], value : Int) -> Unit {
  if values.any(fn(item) { item == value }) {
    return
  }
  values.push(value)
  let mut index = values.length() - 1
  while index > 0 && values[index] < values[index - 1] {
    let previous = values[index - 1]
    values[index - 1] = values[index]
    values[index] = previous
    index = index - 1
  }
}

///|
fn weekday_rank(value : Weekday) -> Int {
  match value {
    Monday => 0
    Tuesday => 1
    Wednesday => 2
    Thursday => 3
    Friday => 4
    Saturday => 5
    Sunday => 6
  }
}

///|
fn insert_weekday_sorted(values : Array[Weekday], value : Weekday) -> Unit {
  if values.any(fn(item) { item == value }) {
    return
  }
  values.push(value)
  let mut index = values.length() - 1
  while index > 0 &&
        weekday_rank(values[index]) < weekday_rank(values[index - 1]) {
    let previous = values[index - 1]
    values[index - 1] = values[index]
    values[index] = previous
    index = index - 1
  }
}

///|
fn parse_int_list(
  value : String,
  field : String,
  minimum : Int,
  maximum : Int,
  forbid_zero : Bool,
) -> Result[Array[Int], Diagnostic] {
  let result = []
  for part in value.split(",") {
    let owned = part.to_owned()
    let number = match parse_integer(owned, field) {
      Ok(item) => item
      Err(error) => return Err(error)
    }
    if number < minimum || number > maximum || (forbid_zero && number == 0) {
      return Err(
        Diagnostic::new(
          "rule.value.range",
          field,
          "selector is outside its supported range",
          minimum.to_string() +
          ".." +
          maximum.to_string() +
          (if forbid_zero { " excluding zero" } else { "" }),
          owned,
        ),
      )
    }
    insert_int_sorted(result, number)
  }
  Ok(result)
}

///|
fn parse_weekday_list(value : String) -> Result[Array[Weekday], Diagnostic] {
  let result = []
  for part in value.split(",") {
    let token = part.to_owned()
    if token.length() != 2 {
      return Err(
        Diagnostic::new(
          "rule.byday.ordinal.unsupported", "BYDAY", "numeric weekday ordinals are outside the supported profile",
          "MO,TU,WE,TH,FR,SA,SU", token,
        ),
      )
    }
    let weekday = match Weekday::parse(token) {
      Ok(item) => item
      Err(error) => return Err(error)
    }
    insert_weekday_sorted(result, weekday)
  }
  Ok(result)
}

///|
fn duplicate_field(field : String) -> Diagnostic {
  Diagnostic::new(
    "rule.field.duplicate", field, "rule field appears more than once", "one value",
    "duplicate",
  )
}

///|
/// Parse a semicolon-separated RFC 5545 recurrence-property value.
pub fn Rule::parse(source : String) -> Result[Rule, Diagnostic] {
  if source.is_empty() {
    return Err(
      Diagnostic::new(
        "rule.empty", "RRULE", "recurrence rule is empty", "FREQ=...", source,
      ),
    )
  }
  let seen : Map[String, Bool] = Map([])
  let mut frequency : Frequency? = None
  let mut interval = 1
  let mut count : Int? = None
  let mut until : Date? = None
  let mut by_weekday : Array[Weekday] = []
  let mut by_month_day : Array[Int] = []
  let mut by_month : Array[Int] = []
  for property in source.split(";") {
    match property.find("=") {
      None =>
        return Err(
          Diagnostic::new(
            "rule.property.syntax",
            "RRULE",
            "property must contain an equals sign",
            "NAME=VALUE",
            property.to_owned(),
          ),
        )
      Some(index) => {
        let field = property[:index].to_owned()
        let value = property[index + 1:].to_owned()
        if field.is_empty() || value.is_empty() {
          return Err(
            Diagnostic::new(
              "rule.property.syntax",
              field,
              "property name and value must be non-empty",
              "NAME=VALUE",
              property.to_owned(),
            ),
          )
        }
        if seen.contains(field) {
          return Err(duplicate_field(field))
        }
        seen[field] = true
        match field {
          "FREQ" =>
            match parse_frequency(value) {
              Ok(item) => frequency = Some(item)
              Err(error) => return Err(error)
            }
          "INTERVAL" => {
            let number = match parse_integer(value, field) {
              Ok(item) => item
              Err(error) => return Err(error)
            }
            if number < 1 || number > 10000 {
              return Err(
                Diagnostic::new(
                  "rule.interval.range", field, "interval must be positive and bounded",
                  "1..10000", value,
                ),
              )
            }
            interval = number
          }
          "COUNT" => {
            let number = match parse_integer(value, field) {
              Ok(item) => item
              Err(error) => return Err(error)
            }
            if number < 1 || number > 100000 {
              return Err(
                Diagnostic::new(
                  "rule.count.range", field, "count must be positive and bounded",
                  "1..100000", value,
                ),
              )
            }
            count = Some(number)
          }
          "UNTIL" =>
            match Date::parse(value) {
              Ok(item) => until = Some(item)
              Err(error) =>
                return Err(
                  Diagnostic::new(
                    "rule.until.invalid",
                    field,
                    "UNTIL is not a valid date",
                    "YYYY-MM-DD",
                    error.actual(),
                  ),
                )
            }
          "BYDAY" =>
            match parse_weekday_list(value) {
              Ok(items) => by_weekday = items
              Err(error) => return Err(error)
            }
          "BYMONTHDAY" =>
            match parse_int_list(value, field, -31, 31, true) {
              Ok(items) => by_month_day = items
              Err(error) => return Err(error)
            }
          "BYMONTH" =>
            match parse_int_list(value, field, 1, 12, false) {
              Ok(items) => by_month = items
              Err(error) => return Err(error)
            }
          "BYSETPOS"
          | "BYYEARDAY"
          | "BYWEEKNO"
          | "BYSECOND"
          | "BYMINUTE"
          | "BYHOUR"
          | "WKST" =>
            return Err(
              Diagnostic::new(
                "rule.field.unsupported", field, "field is outside the supported date-only profile",
                "FREQ,INTERVAL,COUNT,UNTIL,BYDAY,BYMONTHDAY,BYMONTH", field,
              ),
            )
          _ =>
            return Err(
              Diagnostic::new(
                "rule.field.unknown", field, "unknown recurrence rule field", "supported RRULE field",
                field,
              ),
            )
        }
      }
    }
  }
  let actual_frequency = match frequency {
    Some(item) => item
    None =>
      return Err(
        Diagnostic::new(
          "rule.frequency.missing", "FREQ", "every rule requires a frequency", "FREQ=...",
          "missing",
        ),
      )
  }
  if count is Some(_) && until is Some(_) {
    return Err(
      Diagnostic::new(
        "rule.termination.conflict", "RRULE", "COUNT and UNTIL cannot be combined",
        "COUNT or UNTIL", "both",
      ),
    )
  }
  if actual_frequency == Daily && !by_weekday.is_empty() {
    return Err(
      Diagnostic::new(
        "rule.combination.unsupported", "BYDAY", "BYDAY with DAILY is not part of the supported profile",
        "WEEKLY|MONTHLY|YEARLY", "DAILY",
      ),
    )
  }
  Ok({
    frequency: actual_frequency,
    interval,
    count,
    until,
    by_weekday,
    by_month_day,
    by_month,
  })
}

///|
fn append_int_list(builder : StringBuilder, values : Array[Int]) -> Unit {
  for index, value in values {
    if index > 0 {
      builder.write_char(',')
    }
    builder.write_string(value.to_string())
  }
}

///|
/// Render a stable field order with normalized selector ordering and duplicates removed.
pub fn Rule::canonical(self : Rule) -> String {
  let output = StringBuilder::new()
  output.write_string("FREQ=" + self.frequency.name())
  if self.interval != 1 {
    output.write_string(";INTERVAL=" + self.interval.to_string())
  }
  match self.count {
    Some(value) => output.write_string(";COUNT=" + value.to_string())
    None => ()
  }
  match self.until {
    Some(value) => output.write_string(";UNTIL=" + value.to_iso())
    None => ()
  }
  if !self.by_weekday.is_empty() {
    output.write_string(";BYDAY=")
    for index, value in self.by_weekday {
      if index > 0 {
        output.write_char(',')
      }
      output.write_string(value.short_name())
    }
  }
  if !self.by_month_day.is_empty() {
    output.write_string(";BYMONTHDAY=")
    append_int_list(output, self.by_month_day)
  }
  if !self.by_month.is_empty() {
    output.write_string(";BYMONTH=")
    append_int_list(output, self.by_month)
  }
  output.to_string()
}
