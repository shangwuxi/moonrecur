///|
pub(all) struct CommandResult {
  exit_code : Int
  output : String
} derive(Eq, @debug.Debug)

///|
pub let help_text =
  #|MoonRecur 0.1.0
  #|Deterministic civil-calendar recurrence expansion for MoonBit.
  #|
  #|USAGE:
  #|  moonrecur validate --rule RRULE
  #|  moonrecur explain  --rule RRULE
  #|  moonrecur expand   --start DATE --rule RRULE --from DATE --through DATE [--limit N]
  #|
  #|DATES: YYYY-MM-DD
  #|EXIT CODES: 0 success, 2 usage or validation error

///|
fn command_success(output : String) -> CommandResult {
  { exit_code: 0, output }
}

///|
fn command_error(output : String) -> CommandResult {
  { exit_code: 2, output }
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
fn command_int(value : String, field : String) -> Result[Int, String] {
  if value.is_empty() {
    return Err(field + " must be an integer")
  }
  let mut result = 0
  for char in value {
    if char < '0' || char > '9' {
      return Err(field + " must be an integer")
    }
    result = result * 10 + char.to_int() - '0'.to_int()
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
  match expand(start, rule, window) {
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
/// Execute a portable CLI command without performing process I/O.
pub fn execute(args : Array[String]) -> CommandResult {
  if args.is_empty() ||
    args[0] == "help" ||
    args[0] == "--help" ||
    args[0] == "-h" {
    return command_success(help_text)
  }
  match args[0] {
    "validate" => validate_command(args)
    "explain" => explain_command(args)
    "expand" => expand_command(args)
    command => command_error("unknown command: " + command + "\n\n" + help_text)
  }
}
