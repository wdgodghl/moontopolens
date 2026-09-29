///|
test "circle samples and Betti feature curve" {
  let points = @moontopolens.circle_points(8, 1.0)
  let matrix = @moontopolens.distance_matrix(points)
  assert_true((matrix[0][4] - 2.0).abs() < 0.000000001)
  let result = @moontopolens.analyze(@moontopolens.rips(points, threshold=2.0))
  assert_eq(@moontopolens.betti_curve(result, dimension=1, [0.0, 1.0, 2.0]), [
    0, 1, 0,
  ])
}

///|
test "public error message and invalid query parameters" {
  let error = @moontopolens.TopologyError("explanation")
  assert_eq(error.message(), "explanation")
  let result = @moontopolens.analyze(@moontopolens.rips([[0.0]], threshold=0.0))
  let invalid_dimension = try {
    ignore(@moontopolens.diagram(result, 2))
    false
  } catch {
    _ => true
  }
  let invalid_scale = try {
    ignore(@moontopolens.betti(result, 0, 1.0 / 0.0))
    false
  } catch {
    _ => true
  }
  let invalid_cycle = try {
    ignore(@moontopolens.cycle_edges(result, result.intervals[0]))
    false
  } catch {
    _ => true
  }
  let invalid_circle = try {
    ignore(@moontopolens.circle_points(2, 1.0))
    false
  } catch {
    _ => true
  }
  assert_true(
    invalid_dimension && invalid_scale && invalid_cycle && invalid_circle,
  )
}

///|
test "diagram matching validates interval count and infinity" {
  let too_many = Array::make(65, (0.0, 1.0))
  let large = try {
    ignore(@moontopolens.bottleneck(too_many, []))
    false
  } catch {
    _ => true
  }
  let infinite = try {
    ignore(@moontopolens.bottleneck([(0.0, 1.0 / 0.0)], []))
    false
  } catch {
    _ => true
  }
  assert_true(large && infinite)
}

///|
test "requested cutoff is retained even above the last cell" {
  let result = @moontopolens.analyze(@moontopolens.rips([[0.0]], threshold=5.0))
  assert_eq(result.filtration.cutoff, 5.0)
  assert_true(@moontopolens.report_json(result) is { "cutoff": 5, .. })
  assert_true(@moontopolens.barcode_svg(result).contains(">5</text>"))
}
