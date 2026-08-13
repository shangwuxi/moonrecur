///|
fn main {
  let raw_args = @env.args()
  let mut command_index = raw_args.length()
  for index, value in raw_args {
    if command_index == raw_args.length() &&
      (
        value == "validate" ||
        value == "explain" ||
        value == "expand" ||
        value == "help" ||
        value == "--help" ||
        value == "-h"
      ) {
      command_index = index
    }
  }
  let args = if command_index < raw_args.length() {
    raw_args[command_index:].to_owned()
  } else {
    []
  }
  let result = @lib.execute(args)
  if !result.output.is_empty() {
    println(result.output)
  }
  @sys.exit(result.exit_code)
}
