///|
test "selected columns ignore labels and preserve requested order" {
  let text = "label,x,y\na,2,10\nb,4,20\nc,6,30"
  let table = @moontopolens.parse_numeric_csv(text, columns=["y", "x"])
  assert_eq(table.headers, ["y", "x"])
  assert_eq(table.rows, [[10.0, 2.0], [20.0, 4.0], [30.0, 6.0]])
  let normalized = @moontopolens.transform_numeric_csv(
    table,
    normalization="minmax",
  )
  assert_eq(normalized.rows, [[0.0, 0.0], [0.5, 0.5], [1.0, 1.0]])
  for columns in [["missing"], ["x", "x"]] {
    let rejected = try {
      ignore(@moontopolens.parse_numeric_csv(text, columns~))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let rejected = try {
    ignore(@moontopolens.parse_numeric_csv(text))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "population scaling and constant column handling" {
  let table = @moontopolens.parse_numeric_csv("x,constant\n1,7\n3,7")
  assert_eq(
    @moontopolens.transform_numeric_csv(table, normalization="zscore").rows,
    [[-1.0, 0.0], [1.0, 0.0]],
  )
  assert_eq(@moontopolens.transform_numeric_csv(table).rows, table.rows)
  assert_eq(
    @moontopolens.transform_numeric_csv(table, normalization="minmax").rows,
    [[0.0, 0.0], [1.0, 0.0]],
  )
  let request = @moontopolens.csv_request_json(
    "id,v\na,0\nb,1\nc,0\nd,-1\ne,0",
    "series",
    threshold=2.0,
    columns=["v"],
  )
  let result = @moontopolens.analyze_json(request.stringify())
  assert_eq(result.filtration.vertex_count, 4)
  for mode in ["unknown", ""] {
    let rejected = try {
      ignore(@moontopolens.transform_numeric_csv(table, normalization=mode))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
