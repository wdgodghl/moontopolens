///|
test "batch parser accepts named JSON and PGM cases with references" {
  let plan = @moontopolens.parse_batch_manifest(
    "{\"cases\":[{\"name\":\"a\",\"input\":\"a.json\"},{\"name\":\"b\",\"input\":\"b.pgm\",\"format\":\"pgm\",\"threshold\":1}],\"comparisons\":[{\"name\":\"ab\",\"left\":\"a\",\"right\":\"b\"}]}",
  )
  assert_eq(plan.cases.length(), 2)
  assert_eq(plan.cases[0].format, "json")
  assert_eq(plan.cases[1].threshold, Some(1.0))
  assert_eq(plan.cases[1].auto_threshold, false)
  assert_eq(plan.cases[1].invert, false)
  assert_eq(plan.comparisons[0].right, "b")
}

///|
test "batch parser accepts automatic threshold and inversion for PGM" {
  let plan = @moontopolens.parse_batch_manifest(
    "{\"cases\":[{\"name\":\"bright\",\"input\":\"bright.pgm\",\"format\":\"pgm\",\"threshold\":\"auto\",\"invert\":true}]}",
  )
  assert_eq(plan.cases[0].threshold, None)
  assert_true(plan.cases[0].auto_threshold)
  assert_true(plan.cases[0].invert)
}

///|
test "batch parser rejects invalid schemas and references" {
  for
    text in [
      "{}", "{\"cases\":[]}", "{\"cases\":[{\"name\":\"a\",\"input\":\"a.json\"},{\"name\":\"a\",\"input\":\"b.json\"}]}",
      "{\"cases\":[{\"name\":\"bad/name\",\"input\":\"a.json\"}]}", "{\"cases\":[{\"name\":\"a\",\"input\":\"a.pgm\",\"format\":\"pgm\"}]}",
      "{\"cases\":[{\"name\":\"a\",\"input\":\"a.json\",\"threshold\":1}]}", "{\"cases\":[{\"name\":\"a\",\"input\":\"a.json\",\"typo\":1}]}",
      "{\"cases\":[{\"name\":\"a\",\"input\":\"a.json\",\"invert\":true}]}", "{\"cases\":[{\"name\":\"a\",\"input\":\"a.pgm\",\"format\":\"pgm\",\"threshold\":\"automatic\"}]}",
      "{\"cases\":[{\"name\":\"a\",\"input\":\"a.pgm\",\"format\":\"pgm\",\"threshold\":1,\"invert\":1}]}",
      "{\"cases\":[{\"name\":\"a\",\"input\":\"a.json\"}],\"comparisons\":[{\"name\":\"pair\",\"left\":\"a\",\"right\":\"missing\"}]}",
    ] {
    let invalid = try {
      ignore(@moontopolens.parse_batch_manifest(text))
      false
    } catch {
      _ => true
    }
    assert_true(invalid)
  }
}
