///|
test "exact solver escapes a greedy local minimum" {
  let raw : Array[RawCell] = []
  for i = 0; i < 7; i = i + 1 {
    raw.push({
      key: vertex_key(i),
      dimension: 0,
      value: 0.0,
      faces: [],
      vertices: [i],
    })
  }
  for
    (a, b) in [
      (0, 1),
      (0, 2),
      (0, 3),
      (1, 2),
      (1, 3),
      (2, 3),
      (4, 5),
      (4, 6),
      (5, 6),
    ] {
    raw.push({
      key: edge_key(a, b),
      dimension: 1,
      value: 0.0,
      faces: [vertex_key(a), vertex_key(b)],
      vertices: [a, b],
    })
  }
  for (a, b, c) in [(0, 1, 3), (0, 2, 3), (1, 2, 3)] {
    raw.push({
      key: triangle_key(a, b, c),
      dimension: 2,
      value: 0.0,
      faces: [edge_key(a, b), edge_key(a, c), edge_key(b, c)],
      vertices: [a, b, c],
    })
  }
  let result = analyze(finalize(raw, 7, "custom", 0.0))
  let mut selected = -1
  let seed : Array[Int] = []
  for i, cell in result.filtration.cells {
    if cell.dimension == 1 && !cell.vertices.contains(3) {
      seed.push(i)
    }
  }
  for i, interval in result.intervals {
    if interval.dimension == 1 {
      selected = i
      result.intervals[i] = {
        dimension: 1,
        birth: 0.0,
        death: None,
        birth_cell: interval.birth_cell,
        death_cell: None,
        representative: seed,
      }
    }
  }
  assert_eq(simplify_representative(result, selected).length(), 6)
  let exact = shortest_representative(result, selected)
  assert_eq(exact.length(), 3)
  for edge in exact {
    assert_true(result.filtration.cells[edge].vertices[0] >= 4)
  }
  let rejected = try {
    ignore(shortest_representative(result, selected, max_states=4))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
