///|
#cfg(target="js")
fn user_args() -> Array[String] {
  let args = @env.args()
  if args.length() <= 2 {
    []
  } else {
    args[2:].to_owned()
  }
}

///|
#cfg(not(target="js"))
fn user_args() -> Array[String] {
  let args = @env.args()
  if args.is_empty() {
    []
  } else {
    args[1:].to_owned()
  }
}

///|
fn main {
  let result = @lib.execute(user_args())
  if !result.output.is_empty() {
    println(result.output)
  }
  @sys.exit(result.exit_code)
}
