///|
fn expect_invalid(
  action : () -> Unit raise @moontopolens.TopologyError,
) -> Unit raise {
  let rejected = try {
    action()
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "point input rejects dimensions nonfinite and too many points" {
  expect_invalid(() => {
    ignore(@moontopolens.distance_matrix([[0.0], [1.0, 2.0]]))
  })
  expect_invalid(() => ignore(@moontopolens.distance_matrix([[]])))
  expect_invalid(() => ignore(@moontopolens.distance_matrix([[0.0 / 0.0]])))
  expect_invalid(() => {
    ignore(@moontopolens.distance_matrix(Array::makei(129, fn(_) { [0.0] })))
  })
}

///|
test "matrix requires exact symmetry square shape and nonnegative distances" {
  expect_invalid(() => @moontopolens.validate_matrix([[0.0, 1.0], [2.0, 0.0]]))
  expect_invalid(() => @moontopolens.validate_matrix([[1.0]]))
  expect_invalid(() => @moontopolens.validate_matrix([[0.0, -1.0], [-1.0, 0.0]]))
  expect_invalid(() => @moontopolens.validate_matrix([[0.0, 1.0]]))
}

///|
test "cell and work budgets fail without partial results" {
  expect_invalid(() => {
    ignore(
      @moontopolens.rips([[0.0], [1.0], [2.0]], threshold=3.0, max_cells=3),
    )
  })
  expect_invalid(() => ignore(@moontopolens.rips([], threshold=-1.0)))
  expect_invalid(() => {
    ignore(@moontopolens.rips([], threshold=1.0, max_cells=10001))
  })
  let f = @moontopolens.rips([[0.0], [1.0], [2.0], [3.0]], threshold=4.0)
  expect_invalid(() => ignore(@moontopolens.analyze(f, max_additions=1)))
}

///|
test "grid and embedding reject invalid shapes and ranges" {
  expect_invalid(() => {
    ignore(@moontopolens.cubical_grid([[0.0], []], threshold=0.0))
  })
  expect_invalid(() => ignore(@moontopolens.cubical_grid([[]], threshold=0.0)))
  expect_invalid(() => {
    ignore(@moontopolens.delay_embed([0.0], dimension=2, lag=1))
  })
  expect_invalid(() => {
    ignore(@moontopolens.delay_embed([0.0, 1.0], dimension=1, lag=0))
  })
  expect_invalid(() => ignore(@moontopolens.bottleneck([(2.0, 1.0)], [])))
}

///|
test "public filtration mutations are validated before reduction" {
  let f = @moontopolens.rips([[0.0], [1.0]], threshold=1.0)
  f.cells[2].boundary.push(2)
  expect_invalid(() => ignore(@moontopolens.analyze(f)))
}

///|
test "metric computation uses Euclidean norm in multiple dimensions" {
  let matrix = @moontopolens.distance_matrix([[0.0, 0.0, 0.0], [1.0, 2.0, 2.0]])
  assert_eq(matrix[0][1], 3.0)
  assert_eq(matrix[1][0], 3.0)
  assert_eq(matrix[0][0], 0.0)
}
