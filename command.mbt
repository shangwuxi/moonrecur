///|
pub(all) struct CommandResult {
  exit_code : Int
  output : String
} derive(Eq, @debug.Debug)

///|
pub let help_text =
  #|MoonRecur 0.2.1
  #|Deterministic civil-calendar recurrence expansion for MoonBit.
  #|
  #|USAGE:
  #|  moonrecur validate --rule RRULE
  #|  moonrecur explain  --rule RRULE
  #|  moonrecur expand   --start DATE --rule RRULE --from DATE --through DATE [--limit N]
  #|                    [--rdate DATE ...] [--exdate DATE ...]
  #|  moonrecur conflicts --busy LABEL:START..END [--busy LABEL:START..END ...]
  #|  moonrecur free      --from DATE --through DATE [--busy LABEL:START..END ...]
  #|
  #|DATES: YYYY-MM-DD
  #|BUSY SPANS: LABEL:START..END (inclusive)
  #|EXIT CODES: 0 success, 2 usage or validation error

///|
fn command_success(output : String) -> CommandResult {
  { exit_code: 0, output, }
}

///|
fn command_error(output : String) -> CommandResult {
  { exit_code: 2, output, }
}

///|
fn option(args : Array[String], name : String) -> String? {
  for index = 0; index < args.length(); index = index + 1 {
    if args[index] == name && index + 1 < args.length() {
      return Some(args[index + 1])
    }
  }
  None
}

///|
fn options(args : Array[String], name : String) -> Array[String] {
  let values = []
  for index = 0; index < args.length(); index = index + 1 {
    if args[index] == name && index + 1 < args.length() {
      values.push(args[index + 1])
    }
  }
  values
}

///|
fn command_dates(
  args : Array[String],
  name : String,
) -> Result[Array[Date], CommandResult] {
  let result = []
  for source in options(args, name) {
    match Date::parse(source) {
      Ok(date) => result.push(date)
      Err(error) => return Err(command_error(error.to_text()))
    }
  }
  Ok(result)
}

///|
fn parse_busy_span(source : String) -> Result[BusySpan, CommandResult] {
  let colon = match source.find(":") {
    Some(index) => index
    None =>
      return Err(
        command_error(
          "invalid --busy span: expected LABEL:START..END, got " + source,
        ),
      )
  }
  let range = source[colon + 1:]
  let separator = match range.find("..") {
    Some(index) => index
    None =>
      return Err(
        command_error(
          "invalid --busy span: expected LABEL:START..END, got " + source,
        ),
      )
  }
  let label = source[:colon].to_owned()
  let start_source = range[:separator].to_owned()
  let end_source = range[separator + 2:].to_owned()
  let start = match Date::parse(start_source) {
    Ok(value) => value
    Err(error) => return Err(command_error(error.to_text()))
  }
  let end = match Date::parse(end_source) {
    Ok(value) => value
    Err(error) => return Err(command_error(error.to_text()))
  }
  match BusySpan::make(label, start, end) {
    Ok(value) => Ok(value)
    Err(error) => Err(command_error(error.to_text()))
  }
}

///|
fn command_busy_spans(
  args : Array[String],
) -> Result[Array[BusySpan], CommandResult] {
  let result = []
  for index = 0; index < args.length(); index = index + 1 {
    if args[index] == "--busy" {
      if index + 1 >= args.length() || args[index + 1].has_prefix("--") {
        return Err(command_error("missing value for option --busy"))
      }
      match parse_busy_span(args[index + 1]) {
        Ok(value) => result.push(value)
        Err(error) => return Err(error)
      }
    }
  }
  Ok(result)
}

///|
fn conflicts_to_lines(values : Array[Conflict]) -> String {
  let output = StringBuilder()
  for index, value in values {
    if index > 0 {
      output.write_char('\n')
    }
    output.write_string(value.to_text())
  }
  output.to_string()
}

///|
fn free_to_lines(values : Array[FreeSpan]) -> String {
  let output = StringBuilder()
  for index, value in values {
    if index > 0 {
      output.write_char('\n')
    }
    output.write_string(value.to_text())
  }
  output.to_string()
}

///|
fn command_int(value : String, field : String) -> Result[Int, String] {
  if value.is_empty() {
    return Err(field + " must be an integer")
  }
  let mut result = 0
  for char in value {
    if char < '0' || char > '9' {
      return Err(field + " must be an integer")
    }
    let digit = char.to_int() - '0'.to_int()
    if result > (2147483647 - digit) / 10 {
      return Err(field + " exceeds integer range")
    }
    result = result * 10 + digit
  }
  Ok(result)
}

///|
fn required_option(
  args : Array[String],
  name : String,
) -> Result[String, CommandResult] {
  match option(args, name) {
    Some(value) => Ok(value)
    None => Err(command_error("missing required option " + name))
  }
}

///|
fn parse_command_rule(args : Array[String]) -> Result[Rule, CommandResult] {
  let source = match required_option(args, "--rule") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match Rule::parse(source) {
    Ok(rule) => Ok(rule)
    Err(error) => Err(command_error(error.to_text()))
  }
}

///|
fn parse_command_date(
  args : Array[String],
  name : String,
) -> Result[Date, CommandResult] {
  let source = match required_option(args, name) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match Date::parse(source) {
    Ok(date) => Ok(date)
    Err(error) => Err(command_error(error.to_text()))
  }
}

///|
fn validate_command(args : Array[String]) -> CommandResult {
  match parse_command_rule(args) {
    Ok(rule) => command_success("valid: " + rule.canonical())
    Err(error) => error
  }
}

///|
fn explain_command(args : Array[String]) -> CommandResult {
  let rule = match parse_command_rule(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let termination = match (rule.count, rule.until) {
    (Some(count), _) => "count=" + count.to_string()
    (_, Some(until)) => "until=" + until.to_iso()
    _ => "caller window"
  }
  command_success(
    "canonical: " +
    rule.canonical() +
    "\nfrequency: " +
    rule.frequency.name() +
    "\ninterval: " +
    rule.interval.to_string() +
    "\ntermination: " +
    termination,
  )
}

///|
fn expand_command(args : Array[String]) -> CommandResult {
  let rule = match parse_command_rule(args) {
    Ok(value) => value
    Err(error) => return error
  }
  let start = match parse_command_date(args, "--start") {
    Ok(value) => value
    Err(error) => return error
  }
  let from = match parse_command_date(args, "--from") {
    Ok(value) => value
    Err(error) => return error
  }
  let through = match parse_command_date(args, "--through") {
    Ok(value) => value
    Err(error) => return error
  }
  let limit = match option(args, "--limit") {
    None => 1000
    Some(raw) =>
      match command_int(raw, "--limit") {
        Ok(value) => value
        Err(message) => return command_error(message)
      }
  }
  let window = match ExpansionWindow::make(from, through, limit) {
    Ok(value) => value
    Err(error) => return command_error(error.to_text())
  }
  let additions = match command_dates(args, "--rdate") {
    Ok(values) => values
    Err(error) => return error
  }
  let exclusions = match command_dates(args, "--exdate") {
    Ok(values) => values
    Err(error) => return error
  }
  match expand_set(start, rule, window, additions, exclusions) {
    Ok(values) =>
      command_success(
        "occurrences: " +
        values.length().to_string() +
        (if values.is_empty() { "" } else { "\n" + dates_to_lines(values) }),
      )
    Err(error) => command_error(error.to_text())
  }
}

///|
fn conflicts_command(args : Array[String]) -> CommandResult {
  let spans = match command_busy_spans(args) {
    Ok(values) => values
    Err(error) => return error
  }
  if spans.is_empty() {
    return command_error("missing required option --busy")
  }
  let conflicts = find_conflicts(spans)
  command_success(
    "conflicts: " +
    conflicts.length().to_string() +
    (if conflicts.is_empty() {
      ""
    } else {
      "\n" + conflicts_to_lines(conflicts)
    }),
  )
}

///|
fn free_command(args : Array[String]) -> CommandResult {
  let from = match parse_command_date(args, "--from") {
    Ok(value) => value
    Err(error) => return error
  }
  let through = match parse_command_date(args, "--through") {
    Ok(value) => value
    Err(error) => return error
  }
  let spans = match command_busy_spans(args) {
    Ok(values) => values
    Err(error) => return error
  }
  match find_free(from, through, spans) {
    Ok(values) =>
      command_success(
        "free: " +
        values.length().to_string() +
        (if values.is_empty() { "" } else { "\n" + free_to_lines(values) }),
      )
    Err(error) => command_error(error.to_text())
  }
}

///|
fn validate_options(args : Array[String]) -> String? {
  let allowed = match args[0] {
    "validate" | "explain" => ["--rule"]
    "expand" =>
      [
        "--start", "--rule", "--from", "--through", "--limit", "--rdate", "--exdate",
      ]
    "conflicts" => ["--busy"]
    "free" => ["--from", "--through", "--busy"]
    _ => return None
  }
  let seen : Map[String, Bool] = Map([])
  let mut index = 1
  while index < args.length() {
    let name = args[index]
    if !allowed.contains(name) {
      return Some("unknown option: " + name)
    }
    if index + 1 >= args.length() || args[index + 1].has_prefix("--") {
      return Some("missing value for option " + name)
    }
    if seen.contains(name) &&
      name != "--busy" &&
      name != "--rdate" &&
      name != "--exdate" {
      return Some("duplicate option: " + name)
    }
    seen.set(name, true)
    index += 2
  }
  None
}

///|
/// Execute a portable CLI command without performing process I/O.
pub fn execute(args : Array[String]) -> CommandResult {
  if args.is_empty() ||
    args[0] == "help" ||
    args[0] == "--help" ||
    args[0] == "-h" {
    return command_success(help_text)
  }
  match validate_options(args) {
    Some(message) => return command_error(message)
    None => ()
  }
  match args[0] {
    "validate" => validate_command(args)
    "explain" => explain_command(args)
    "expand" => expand_command(args)
    "conflicts" => conflicts_command(args)
    "free" => free_command(args)
    command => command_error("unknown command: " + command + "\n\n" + help_text)
  }
}
