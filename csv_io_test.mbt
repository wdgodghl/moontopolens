///|
test "CSV quotes BOM CRLF and preview preserve data" {
  let table = @moontopolens.parse_numeric_csv(
    "\uFEFF\"x,coordinate\",\"y\"\r\n\"0\",0\r\n1,0\r\n1,1\r\n0,1\r\n",
  )
  assert_eq(table.headers, ["x,coordinate", "y"])
  assert_eq(table.rows, [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]])
  assert_true(
    @moontopolens.csv_preview_json(table)
    .stringify()
    .contains("\"row_count\":4"),
  )
  let escaped = @moontopolens.parse_numeric_csv("\"a\"\"b\"\n1e-2\n")
  assert_eq(escaped.headers, ["a\"b"])
  assert_eq(escaped.rows, [[0.01]])
}

///|
test "CSV point and series requests preserve known diagrams" {
  let points = @moontopolens.csv_request_json(
    "x,y\n0,0\n1,0\n1,1\n0,1",
    "points",
    threshold=2.0,
  )
  let result = @moontopolens.analyze_json(points.stringify())
  assert_eq(@moontopolens.betti(result, 1, 1.0), 1)
  assert_eq(@moontopolens.betti(result, 1, 1.5), 0)
  let series = @moontopolens.csv_request_json(
    "value\n0\n1\n0\n-1\n0\n1\n0\n-1\n0",
    "series",
    threshold=2.0,
  )
  let embedded = @moontopolens.analyze_json(series.stringify())
  assert_eq(@moontopolens.betti(embedded, 1, 1.5), 1)
  assert_eq(@moontopolens.betti(embedded, 1, 2.0), 0)
}

///|
test "CSV rejects ambiguous schemas missing cells text and malformed quotes" {
  for
    text in [
      "", "x,y", "x,x\n1,2", "x,\n1,2", "x,y\n1", "x,y\n1,", "x\nNaN", "x\ntrue",
      "x\nnull", "x\n1e101", "x\n\"1", "x\n\"1\"bad", "x\n1\"", "\"multi\nline\"\n1",
    ] {
    let rejected = try {
      ignore(@moontopolens.parse_numeric_csv(text))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let rejected = try {
    ignore(@moontopolens.csv_request_json("x,y\n1,2", "series", threshold=1.0))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "CSV respects input point row column and field budgets" {
  for
    text in [
      "x\n" + "1\n".repeat(10001),
      "x" + ",y".repeat(32) + "\n1" + ",1".repeat(32),
      "a".repeat(257) + "\n1",
      "x\n" + "1".repeat(1000000),
    ] {
    let rejected = try {
      ignore(@moontopolens.parse_numeric_csv(text))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let rejected = try {
    ignore(
      @moontopolens.csv_request_json(
        "x\n" + "1\n".repeat(129),
        "points",
        threshold=1.0,
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
