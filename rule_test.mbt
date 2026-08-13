///|
test "parse and canonicalize weekly rule deterministically" {
  let rule = @moonrecur.Rule::parse(
    "BYDAY=FR,MO,WE,MO;COUNT=8;INTERVAL=2;FREQ=WEEKLY",
  ).unwrap()
  assert_eq(rule.canonical(), "FREQ=WEEKLY;INTERVAL=2;COUNT=8;BYDAY=MO,WE,FR")
  assert_eq(rule.frequency.name(), "WEEKLY")
  assert_eq(rule.interval, 2)
}

///|
test "parse negative month days and normalize numeric lists" {
  let rule = @moonrecur.Rule::parse(
    "FREQ=MONTHLY;UNTIL=2026-12-31;BYMONTHDAY=-1,15,-1;BYMONTH=12,2,2",
  ).unwrap()
  assert_eq(
    rule.canonical(),
    "FREQ=MONTHLY;UNTIL=2026-12-31;BYMONTHDAY=-1,15;BYMONTH=2,12",
  )
}

///|
test "reject missing and duplicate frequency" {
  guard @moonrecur.Rule::parse("COUNT=3") is Err(missing) else {
    fail("expected missing frequency")
  }
  assert_eq(missing.code(), "rule.frequency.missing")
  guard @moonrecur.Rule::parse("FREQ=DAILY;FREQ=WEEKLY") is Err(duplicate) else {
    fail("expected duplicate")
  }
  assert_eq(duplicate.code(), "rule.field.duplicate")
}

///|
test "reject conflicting termination and invalid ranges" {
  guard @moonrecur.Rule::parse("FREQ=DAILY;COUNT=2;UNTIL=2026-01-01")
    is Err(conflict) else {
    fail("expected conflict")
  }
  assert_eq(conflict.code(), "rule.termination.conflict")
  guard @moonrecur.Rule::parse("FREQ=MONTHLY;BYMONTHDAY=0") is Err(range) else {
    fail("expected range error")
  }
  assert_eq(range.code(), "rule.value.range")
}

///|
test "reject unknown and explicitly unsupported fields" {
  guard @moonrecur.Rule::parse("FREQ=WEEKLY;COLOR=BLUE") is Err(unknown) else {
    fail("expected unknown field")
  }
  assert_eq(unknown.code(), "rule.field.unknown")
  guard @moonrecur.Rule::parse("FREQ=YEARLY;BYWEEKNO=2") is Err(unsupported) else {
    fail("expected unsupported field")
  }
  assert_eq(unsupported.code(), "rule.field.unsupported")
}

///|
test "reject ordinal weekdays and malformed properties" {
  guard @moonrecur.Rule::parse("FREQ=MONTHLY;BYDAY=1MO") is Err(ordinal) else {
    fail("expected ordinal rejection")
  }
  assert_eq(ordinal.code(), "rule.byday.ordinal.unsupported")
  guard @moonrecur.Rule::parse("FREQ") is Err(syntax) else {
    fail("expected property syntax error")
  }
  assert_eq(syntax.code(), "rule.property.syntax")
}
