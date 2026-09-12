///|
/// Caller bounds for recurrence expansion.
pub(all) struct ExpansionWindow {
  from : Date
  through : Date
  limit : Int
} derive(Eq, @debug.Debug)

///|
pub fn ExpansionWindow::make(
  from : Date,
  through : Date,
  limit : Int,
) -> Result[ExpansionWindow, Diagnostic] {
  if through.is_before(from) {
    return Err(
      Diagnostic::new(
        "expand.window.order",
        "window",
        "window end precedes its start",
        "from <= through",
        from.to_iso() + ".." + through.to_iso(),
      ),
    )
  }
  if limit < 1 || limit > 100000 {
    return Err(
      Diagnostic::new(
        "expand.limit.range",
        "limit",
        "result limit must be positive and bounded",
        "1..100000",
        limit.to_string(),
      ),
    )
  }
  Ok({ from, through, limit, })
}

///|
fn weekday_index(value : Weekday) -> Int {
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
fn months_between(start : Date, candidate : Date) -> Int {
  (candidate.year - start.year) * 12 + candidate.month - start.month
}

///|
fn years_between(start : Date, candidate : Date) -> Int {
  candidate.year - start.year
}

///|
fn matches_period(rule : Rule, start : Date, candidate : Date) -> Bool {
  match rule.frequency {
    Daily =>
      (candidate.epoch_day() - start.epoch_day()) % rule.interval.to_int64() ==
      0L
    Weekly => {
      let start_monday = start.epoch_day() -
        weekday_index(start.weekday()).to_int64()
      let candidate_monday = candidate.epoch_day() -
        weekday_index(candidate.weekday()).to_int64()
      (candidate_monday - start_monday) / 7L % rule.interval.to_int64() == 0L
    }
    Monthly => months_between(start, candidate) % rule.interval == 0
    Yearly => years_between(start, candidate) % rule.interval == 0
  }
}

///|
fn resolved_month_day(candidate : Date, selector : Int) -> Int {
  if selector > 0 {
    selector
  } else {
    days_in_month(candidate.year, candidate.month) + selector + 1
  }
}

///|
fn matches_selectors(rule : Rule, start : Date, candidate : Date) -> Bool {
  if !rule.by_month.is_empty() &&
    !rule.by_month.any(fn(value) { value == candidate.month }) {
    return false
  }
  if !rule.by_month_day.is_empty() &&
    !rule.by_month_day.any(fn(value) {
      resolved_month_day(candidate, value) == candidate.day
    }) {
    return false
  }
  if !rule.by_weekday.is_empty() &&
    !rule.by_weekday.any(fn(value) { value == candidate.weekday() }) {
    return false
  }
  if rule.by_month_day.is_empty() && rule.by_weekday.is_empty() {
    match rule.frequency {
      Daily => ()
      Weekly => if candidate.weekday() != start.weekday() { return false }
      Monthly => if candidate.day != start.day { return false }
      Yearly =>
        if candidate.day != start.day ||
          (rule.by_month.is_empty() && candidate.month != start.month) {
          return false
        }
    }
  }
  true
}

///|
fn effective_end(rule : Rule, window : ExpansionWindow) -> Date {
  match rule.until {
    Some(value) =>
      if value.is_before(window.through) {
        value
      } else {
        window.through
      }
    None => window.through
  }
}

///|
/// Expand a validated rule from DTSTART into a finite, inclusive date window.
pub fn expand(
  start : Date,
  rule : Rule,
  window : ExpansionWindow,
) -> Result[Array[Date], Diagnostic] {
  if window.through.is_before(start) {
    return Ok([])
  }
  match rule.until {
    Some(value) =>
      if value.is_before(start) {
        return Err(
          Diagnostic::new(
            "expand.until.before_start",
            "UNTIL",
            "rule ends before DTSTART",
            ">= " + start.to_iso(),
            value.to_iso(),
          ),
        )
      }
    None => ()
  }
  let scan_end = effective_end(rule, window)
  let scan_days = scan_end.epoch_day() - start.epoch_day()
  if scan_days > 366000L {
    return Err(
      Diagnostic::new(
        "expand.scan.too_large",
        "window",
        "window exceeds the safe scan span",
        "at most 366000 days",
        scan_days.to_string(),
      ),
    )
  }
  let output = []
  let mut candidate = start
  let mut matched = 0
  let mut finished = false
  while !finished && !candidate.is_after(scan_end) {
    if matches_period(rule, start, candidate) &&
      matches_selectors(rule, start, candidate) {
      matched = matched + 1
      let before_count_end = match rule.count {
        Some(count) => matched <= count
        None => true
      }
      if before_count_end && !candidate.is_before(window.from) {
        output.push(candidate)
        if output.length() >= window.limit {
          finished = true
        }
      }
      match rule.count {
        Some(count) => if matched >= count { finished = true }
        None => ()
      }
    }
    if !finished {
      match candidate.add_days(1) {
        Ok(next) => candidate = next
        Err(_) => finished = true
      }
    }
  }
  Ok(output)
}

///|
fn insert_date_sorted(values : Array[Date], value : Date) -> Unit {
  if values.any(fn(item) { item == value }) {
    return
  }
  values.push(value)
  let mut index = values.length() - 1
  while index > 0 && values[index].is_before(values[index - 1]) {
    let previous = values[index - 1]
    values[index - 1] = values[index]
    values[index] = previous
    index = index - 1
  }
}

///|
/// Expand a rule, add RDATE values, then remove EXDATE values.
pub fn expand_set(
  start : Date,
  rule : Rule,
  window : ExpansionWindow,
  additions : Array[Date],
  exclusions : Array[Date],
) -> Result[Array[Date], Diagnostic] {
  let base = match expand(start, rule, window) {
    Ok(values) => values
    Err(error) => return Err(error)
  }
  for value in additions {
    if !value.is_before(window.from) && !value.is_after(window.through) {
      insert_date_sorted(base, value)
    }
  }
  let result = []
  for value in base {
    if !exclusions.any(fn(item) { item == value }) &&
      result.length() < window.limit {
      result.push(value)
    }
  }
  Ok(result)
}

///|
pub fn dates_to_lines(values : Array[Date]) -> String {
  let output = StringBuilder()
  for index, value in values {
    if index > 0 {
      output.write_char('\n')
    }
    output.write_string(value.to_iso())
  }
  output.to_string()
}
