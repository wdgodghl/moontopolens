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
  let scaled = @moontopolens.transform_numeric_csv(
      table,
      normalization="zscore",
    ).rows
  assert_true((scaled[0][0] + 1.0).abs() < 1.0e-12)
  assert_true((scaled[1][0] - 1.0).abs() < 1.0e-12)
  assert_eq(scaled[0][1], 0.0)
  assert_eq(scaled[1][1], 0.0)
  assert_eq(@moontopolens.transform_numeric_csv(table).rows, table.rows)
  assert_eq(
    @moontopolens.transform_numeric_csv(table, normalization="minmax").rows,
    [[0.0, 0.0], [1.0, 0.0]],
  )
  let many = @moontopolens.parse_numeric_csv("x\n" + "7\n".repeat(1000))
  let tiny = @moontopolens.transform_numeric_csv(
    @moontopolens.parse_numeric_csv("x\n1e-200\n3e-200"),
    normalization="zscore",
  )
  assert_true((tiny.rows[0][0] + 1.0).abs() < 1.0e-12)
  assert_true((tiny.rows[1][0] - 1.0).abs() < 1.0e-12)
  assert_true(
    @moontopolens.transform_numeric_csv(many, normalization="zscore").rows.all(fn(
      row,
    ) {
      row[0] == 0.0
    }),
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

///|
test "deterministic sampling coverage, ties and identity" {
  let points = [[0.0], [1.0], [2.0], [3.0]]
  let sample = @moontopolens.sample_points(points, size=2)
  assert_eq(sample.source_indices, [0, 3])
  assert_eq(sample.covering_radius, 1.0)
  assert_eq(sample.points, [[0.0], [3.0]])
  assert_eq(@moontopolens.sample_points(points, size=4).source_indices, [
    0, 1, 2, 3,
  ])
  assert_eq(
    @moontopolens.sample_points([[0.0], [0.0], [0.0], [0.0]], size=3).source_indices,
    [0, 1, 2],
  )
  for size in [0, 129] {
    let rejected = try {
      ignore(@moontopolens.sample_points(points, size~))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  for rows in [[], [[0.0], [1.0, 2.0]], [[]]] {
    let rejected = try {
      ignore(@moontopolens.sample_points(rows, size=2))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let text = "x\n0\n1\n2\n3"
  let request = @moontopolens.csv_request_json(
    text,
    "points",
    threshold=4.0,
    sample_size=2,
  )
  assert_eq(
    @moontopolens.analyze_json(request.stringify()).filtration.vertex_count,
    2,
  )
}
