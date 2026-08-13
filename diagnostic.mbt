///|
/// A stable, machine-readable error produced while parsing or validating input.
pub struct Diagnostic {
  code : String
  field : String
  message : String
  expected : String
  actual : String
} derive(Eq, @debug.Debug)

///|
pub fn Diagnostic::new(
  code : String,
  field : String,
  message : String,
  expected : String,
  actual : String,
) -> Diagnostic {
  { code, field, message, expected, actual }
}

///|
pub fn Diagnostic::code(self : Diagnostic) -> String {
  self.code
}

///|
pub fn Diagnostic::field(self : Diagnostic) -> String {
  self.field
}

///|
pub fn Diagnostic::message(self : Diagnostic) -> String {
  self.message
}

///|
pub fn Diagnostic::expected(self : Diagnostic) -> String {
  self.expected
}

///|
pub fn Diagnostic::actual(self : Diagnostic) -> String {
  self.actual
}

///|
pub fn Diagnostic::to_text(self : Diagnostic) -> String {
  self.code +
  " at " +
  self.field +
  ": " +
  self.message +
  " (expected " +
  self.expected +
  ", got " +
  self.actual +
  ")"
}
