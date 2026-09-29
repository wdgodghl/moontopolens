///|
test "square loop births at side and dies at diagonal" {
  let points = [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]]
  let result = @moontopolens.analyze(@moontopolens.rips(points, threshold=2.0))
  assert_eq(@moontopolens.betti(result, 0, 0.0), 4)
  assert_eq(@moontopolens.betti(result, 0, 1.0), 1)
  assert_eq(@moontopolens.betti(result, 1, 1.0), 1)
  assert_eq(@moontopolens.betti(result, 1, 2.0), 0)
  let h1 = result.intervals.filter(fn(i) { i.dimension == 1 })
  assert_eq(h1.length(), 1)
  assert_eq(h1[0].birth, 1.0)
  assert_true(h1[0].death is Some(d) && (d - 2.0.sqrt()).abs() < 0.000000001)
  assert_eq(@moontopolens.cycle_edges(result, h1[0]).length(), 4)
}

///|
test "truncated square retains essential H1" {
  let result = @moontopolens.analyze(
    @moontopolens.rips(
      [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]],
      threshold=1.0,
    ),
  )
  assert_eq(@moontopolens.betti(result, 1, 1.0), 1)
  assert_true(
    result.intervals.any(fn(i) { i.dimension == 1 && i.death is None }),
  )
}

///|
test "triangle has no positive lifetime loop and empty input works" {
  let triangle = @moontopolens.analyze(
    @moontopolens.rips([[0.0], [1.0], [2.0]], threshold=2.0),
  )
  assert_eq(@moontopolens.diagram(triangle, 1).length(), 0)
  let all = @moontopolens.analyze(
    @moontopolens.rips([[0.0], [1.0], [2.0]], threshold=2.0),
    include_zero=true,
  )
  assert_true(all.intervals.length() > triangle.intervals.length())
  let empty = @moontopolens.analyze(@moontopolens.rips([], threshold=1.0))
  assert_eq(empty.intervals.length(), 0)
}

///|
test "duplicate points cancel zero length components" {
  let f = @moontopolens.rips([[2.0], [2.0], [3.0]], threshold=2.0)
  let result = @moontopolens.analyze(f)
  assert_eq(@moontopolens.betti(result, 0, 0.0), 2)
  assert_eq(@moontopolens.betti(result, 0, 1.0), 1)
}

///|
test "two separated clusters stay disconnected at cutoff" {
  let result = @moontopolens.analyze(
    @moontopolens.rips([[0.0], [0.1], [10.0], [10.1]], threshold=0.2),
  )
  assert_eq(@moontopolens.betti(result, 0, 0.2), 2)
  assert_eq(@moontopolens.betti(result, 1, 0.2), 0)
}

///|
test "cubical image ring closes when center enters" {
  let grid = [[0.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 0.0]]
  let ring = @moontopolens.analyze(
    @moontopolens.cubical_grid(grid, threshold=1.0),
  )
  assert_eq(@moontopolens.betti(ring, 0, 0.0), 1)
  assert_eq(@moontopolens.betti(ring, 1, 0.0), 1)
  assert_eq(@moontopolens.betti(ring, 1, 1.0), 0)
  let h1 = ring.intervals.filter(fn(i) { i.dimension == 1 })
  assert_eq(h1[0].birth, 0.0)
  assert_true(h1[0].death is Some(1.0))
  assert_eq(@moontopolens.cycle_edges(ring, h1[0]).length(), 8)
}

///|
test "negative grid values and empty grids" {
  let result = @moontopolens.analyze(
    @moontopolens.cubical_grid([[-2.0, -1.0]], threshold=0.0),
  )
  assert_eq(@moontopolens.betti(result, 0, -2.0), 1)
  assert_eq(@moontopolens.betti(result, 0, -1.0), 1)
  assert_eq(@moontopolens.cubical_grid([], threshold=0.0).cells.length(), 0)
  assert_eq(
    @moontopolens.cubical_grid([[1.0]], threshold=0.0).cells.length(),
    0,
  )
}

///|
test "delay embedding uses lag and stride exactly" {
  let embedded = @moontopolens.delay_embed(
    [0.0, 1.0, 2.0, 3.0, 4.0],
    dimension=2,
    lag=2,
    stride=2,
  )
  assert_eq(embedded.length(), 2)
  assert_eq(embedded[0], [0.0, 2.0])
  assert_eq(embedded[1], [2.0, 4.0])
}

///|
test "finite bottleneck diagonal matching and symmetry" {
  assert_eq(@moontopolens.bottleneck([], []), 0.0)
  assert_eq(@moontopolens.bottleneck([(0.0, 4.0)], []), 2.0)
  assert_eq(@moontopolens.bottleneck([(0.0, 4.0)], [(1.0, 5.0)]), 1.0)
  assert_eq(@moontopolens.bottleneck([(0.0, 2.0)], [(5.0, 7.0)]), 1.0)
  let a = [(0.0, 5.0), (2.0, 3.0)]
  let b = [(1.0, 6.0)]
  assert_eq(@moontopolens.bottleneck(a, b), @moontopolens.bottleneck(b, a))
}

///|
test "essential interval count mismatch cannot be finitely matched" {
  let a = @moontopolens.analyze(
    @moontopolens.rips([[0.0], [1.0]], threshold=0.0),
  )
  let b = @moontopolens.analyze(
    @moontopolens.rips([[0.0], [1.0]], threshold=1.0),
  )
  assert_true(@moontopolens.compare_analyses(a, b, dimension=0) is None)
  assert_true(@moontopolens.compare_analyses(b, b, dimension=0) is Some(0.0))
}
