///|
test "JSON analysis and report round trip" {
  let result = @moontopolens.analyze_json(
    "{\"kind\":\"matrix\",\"threshold\":2,\"matrix\":[[0,1,2,1],[1,0,1,2],[2,1,0,1],[1,2,1,0]]}",
  )
  assert_eq(@moontopolens.betti(result, 1, 1.5), 1)
  let report = @moontopolens.report_json(result)
  assert_eq(@json.parse(report.stringify()), report)
  assert_true(report is { "schema_version": 1, "coefficients": "GF(2)", .. })
  assert_true(@moontopolens.barcode_svg(result).contains("Persistence barcode"))
  assert_true(@moontopolens.diagram_svg(result).contains("Persistence diagram"))
}

///|
test "all JSON input kinds are runnable" {
  let points = @moontopolens.analyze_json(
    "{\"kind\":\"points\",\"threshold\":1,\"points\":[[0],[1]]}",
  )
  assert_eq(@moontopolens.betti(points, 0, 1.0), 1)
  let grid = @moontopolens.analyze_json(
    "{\"kind\":\"grid\",\"threshold\":0,\"grid\":[[0,0],[0,0]]}",
  )
  assert_eq(@moontopolens.betti(grid, 1, 0.0), 0)
  let series = @moontopolens.analyze_json(
    "{\"kind\":\"series\",\"threshold\":3,\"series\":[0,1,0,-1,0]}",
  )
  assert_eq(series.filtration.vertex_count, 4)
  assert_eq(@moontopolens.betti(series, 1, 1.5), 1)
}

///|
test "bad JSON and wrong field types reject consistently" {
  let bad = [
    "{", "[]", "{}", "{\"kind\":7,\"threshold\":1}", "{\"kind\":\"unknown\",\"threshold\":1}",
    "{\"kind\":\"points\",\"threshold\":\"x\",\"points\":[]}", "{\"kind\":\"points\",\"threshold\":1,\"points\":[true]}",
    "{\"kind\":\"points\",\"threshold\":1,\"points\":[],\"threshhold\":2}", "{\"kind\":\"points\",\"threshold\":1,\"points\":[],\"max_cells\":1.5}",
    "{\"kind\":\"series\",\"threshold\":1,\"series\":[\"x\"]}",
  ]
  for text in bad {
    let rejected = try {
      ignore(@moontopolens.analyze_json(text))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "empty negative and long barcode rendering is valid" {
  let empty = @moontopolens.analyze(@moontopolens.rips([], threshold=0.0))
  assert_true(@moontopolens.barcode_svg(empty).has_suffix("</svg>"))
  let many = @moontopolens.analyze(
    @moontopolens.rips(
      Array::makei(90, fn(i) { [i.to_double()] }),
      threshold=0.0,
    ),
  )
  assert_true(@moontopolens.barcode_svg(many).contains("first 80 intervals"))
  let negative = @moontopolens.analyze(
    @moontopolens.cubical_grid([[-3.0, -2.0]], threshold=0.0),
  )
  assert_true(!@moontopolens.diagram_svg(negative).contains("NaN"))
}
