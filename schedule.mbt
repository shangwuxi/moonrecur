///|
/// An inclusive all-day occupied range with a caller-defined label.
pub(all) struct BusySpan {
  label : String
  start : Date
  end : Date
} derive(Eq, @debug.Debug)

///|
/// A pair of source spans whose inclusive ranges overlap.
pub(all) struct Conflict {
  left_label : String
  right_label : String
  overlap_start : Date
  overlap_end : Date
} derive(Eq, @debug.Debug)

///|
/// An inclusive all-day range that contains no busy span.
pub(all) struct FreeSpan {
  start : Date
  end : Date
} derive(Eq, @debug.Debug)

///|
pub fn BusySpan::make(
  label : String,
  start : Date,
  end : Date,
) -> Result[BusySpan, Diagnostic] {
  if label.trim().is_empty() {
    return Err(
      Diagnostic::new(
        "schedule.label.empty", "label", "busy span label cannot be empty", "non-empty label",
        label,
      ),
    )
  }
  if end.is_before(start) {
    return Err(
      Diagnostic::new(
        "schedule.span.order",
        "span",
        "busy span end precedes its start",
        "start <= end",
        start.to_iso() + ".." + end.to_iso(),
      ),
    )
  }
  Ok({ label, start, end })
}

///|
pub fn BusySpan::to_text(self : BusySpan) -> String {
  self.label + ":" + self.start.to_iso() + ".." + self.end.to_iso()
}

///|
pub fn Conflict::to_text(self : Conflict) -> String {
  self.left_label +
  " <> " +
  self.right_label +
  ":" +
  self.overlap_start.to_iso() +
  ".." +
  self.overlap_end.to_iso()
}

///|
pub fn FreeSpan::to_text(self : FreeSpan) -> String {
  self.start.to_iso() + ".." + self.end.to_iso()
}

///|
fn later_date(left : Date, right : Date) -> Date {
  if left.is_after(right) {
    left
  } else {
    right
  }
}

///|
fn earlier_date(left : Date, right : Date) -> Date {
  if left.is_before(right) {
    left
  } else {
    right
  }
}

///|
fn spans_overlap(left : BusySpan, right : BusySpan) -> Bool {
  !left.end.is_before(right.start) && !right.end.is_before(left.start)
}

///|
/// Return every conflicting source pair, preserving caller order.
pub fn find_conflicts(spans : Array[BusySpan]) -> Array[Conflict] {
  let result = []
  for left_index = 0; left_index < spans.length(); left_index = left_index + 1 {
    for right_index = left_index + 1
        right_index < spans.length()
        right_index = right_index + 1 {
      let left = spans[left_index]
      let right = spans[right_index]
      if spans_overlap(left, right) {
        result.push({
          left_label: left.label,
          right_label: right.label,
          overlap_start: later_date(left.start, right.start),
          overlap_end: earlier_date(left.end, right.end),
        })
      }
    }
  }
  result
}

///|
fn insert_span_by_start(values : Array[BusySpan], value : BusySpan) -> Unit {
  values.push(value)
  let mut index = values.length() - 1
  while index > 0 &&
        (
          values[index].start.is_before(values[index - 1].start) ||
          (
            values[index].start == values[index - 1].start &&
            values[index].end.is_before(values[index - 1].end)
          )
        ) {
    let previous = values[index - 1]
    values[index - 1] = values[index]
    values[index] = previous
    index = index - 1
  }
}

///|
/// Sort and merge overlapping or adjacent spans. Labels are joined for traceability.
pub fn merge_busy(spans : Array[BusySpan]) -> Array[BusySpan] {
  let sorted = []
  for value in spans {
    insert_span_by_start(sorted, value)
  }
  let result = []
  for value in sorted {
    if result.is_empty() {
      result.push(value)
    } else {
      let last_index = result.length() - 1
      let last = result[last_index]
      let adjacent = match last.end.add_days(1) {
        Ok(next) => !value.start.is_after(next)
        Err(_) => true
      }
      if adjacent {
        result[last_index] = {
          label: last.label + "+" + value.label,
          start: last.start,
          end: if value.end.is_after(last.end) {
            value.end
          } else {
            last.end
          },
        }
      } else {
        result.push(value)
      }
    }
  }
  result
}

///|
/// Find inclusive free ranges inside a query window after clipping and merging busy spans.
pub fn find_free(
  window_start : Date,
  window_end : Date,
  spans : Array[BusySpan],
) -> Result[Array[FreeSpan], Diagnostic] {
  if window_end.is_before(window_start) {
    return Err(
      Diagnostic::new(
        "schedule.window.order",
        "window",
        "query window end precedes its start",
        "start <= end",
        window_start.to_iso() + ".." + window_end.to_iso(),
      ),
    )
  }
  let clipped = []
  for value in spans {
    if !value.end.is_before(window_start) && !value.start.is_after(window_end) {
      clipped.push({
        label: value.label,
        start: later_date(value.start, window_start),
        end: earlier_date(value.end, window_end),
      })
    }
  }
  let busy = merge_busy(clipped)
  let result = []
  let mut cursor = window_start
  let mut exhausted = false
  for value in busy {
    if cursor.is_before(value.start) {
      match value.start.add_days(-1) {
        Ok(end) => result.push({ start: cursor, end })
        Err(_) => ()
      }
    }
    match value.end.add_days(1) {
      Ok(next) => cursor = next
      Err(_) => exhausted = true
    }
  }
  if !exhausted && !cursor.is_after(window_end) {
    result.push({ start: cursor, end: window_end })
  }
  Ok(result)
}

///|
/// Convert occurrence dates to fixed-duration inclusive spans.
pub fn occurrences_to_busy(
  label : String,
  occurrences : Array[Date],
  duration_days : Int,
) -> Result[Array[BusySpan], Diagnostic] {
  if duration_days < 1 || duration_days > 3660 {
    return Err(
      Diagnostic::new(
        "schedule.duration.range",
        "duration",
        "duration must be positive and bounded",
        "1..3660 days",
        duration_days.to_string(),
      ),
    )
  }
  let result = []
  for date in occurrences {
    let end = match date.add_days(duration_days - 1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    match BusySpan::make(label, date, end) {
      Ok(value) => result.push(value)
      Err(error) => return Err(error)
    }
  }
  Ok(result)
}
