///|
test "ranked intervals preserve source and use censored lifetime lower bounds" {
  let result = @moontopolens.analyze(
    @moontopolens.rips([[0.0], [1.0], [3.0]], threshold=4.0),
  )
  let ranked = @moontopolens.ranked_intervals(result, dimension=0)
  assert_eq(ranked.length(), 3)
  assert_true(ranked[0].death is None)
  assert_eq(@moontopolens.observed_lifetime(result, ranked[0]), 4.0)
  let finite = @moontopolens.ranked_intervals(
    result,
    dimension=0,
    min_lifetime=1.5,
    include_alive=false,
  )
  assert_eq(finite.length(), 1)
  assert_eq(@moontopolens.observed_lifetime(result, finite[0]), 2.0)
  assert_eq(result.intervals[0].birth_cell, 0)
  let invalid = try {
    ignore(
      @moontopolens.ranked_intervals(result, dimension=1, min_lifetime=-1.0),
    )
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
test "summary entropy excludes censored classes and reflects two equal holes" {
  let grid = [
    [0.0, 0.0, 0.0, 0.0, 0.0],
    [0.0, 1.0, 0.0, 1.0, 0.0],
    [0.0, 0.0, 0.0, 0.0, 0.0],
  ]
  let result = @moontopolens.analyze(
    @moontopolens.cubical_grid(grid, threshold=1.0),
  )
  assert_eq(@moontopolens.betti(result, 1, 0.0), 2)
  assert_eq(@moontopolens.betti(result, 1, 1.0), 0)
  assert_true(
    @moontopolens.summary_json(result)
    is [
      _,
      {
        "finite_count": 2,
        "alive_at_cutoff": 0,
        "longest_finite_lifetime": 1,
        ..
      },
    ],
  )
  let summary = @moontopolens.summary_json(result)
  let entropy = match summary {
    [_, { "finite_persistence_entropy": Number(n, ..), .. }] => n
    _ => -1.0
  }
  assert_true((entropy - @math.ln(2.0)).abs() < 0.000000001)
}

///|
test "CSV exports include cutoff samples and essential blanks" {
  let result = @moontopolens.analyze(
    @moontopolens.rips([[0.0], [1.0]], threshold=1.0),
  )
  let csv = @moontopolens.intervals_csv(result)
  assert_true(csv.contains(",,true,"))
  assert_true(@moontopolens.betti_csv(result, samples=3).contains("1,1,0\n"))
  let invalid = try {
    ignore(@moontopolens.betti_csv(result, samples=1))
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
test "report coordinates are projection only and grids retain vertex indices" {
  let points = @moontopolens.rips(
    [[0.0, 2.0, 10.0], [1.0, 3.0, 10.0]],
    threshold=2.0,
  )
  assert_eq(points.positions, [[0.0, 2.0], [1.0, 3.0]])
  let matrix = @moontopolens.rips_matrix(
    [[0.0, 1.0], [1.0, 0.0]],
    threshold=1.0,
  )
  assert_eq(matrix.positions.length(), 0)
  let grid = @moontopolens.cubical_grid([[1.0, 0.0], [0.0, 0.0]], threshold=0.0)
  assert_eq(grid.positions[2], [0.0, -1.0])
  assert_eq(grid.vertex_count, 3)
}
