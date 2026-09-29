// Independent dense row elimination oracle, intentionally unlike sparse columns.

///|
fn dense_rank(columns : Array[Array[Int]], row_count : Int) -> Int {
  let rows = Array::makei(row_count, fn(_) {
    Array::make(columns.length(), false)
  })
  for j = 0; j < columns.length(); j = j + 1 {
    for i in columns[j] {
      rows[i][j] = !rows[i][j]
    }
  }
  let mut rank = 0
  for j = 0; j < columns.length(); j = j + 1 {
    let mut pivot = rank
    while pivot < row_count && !rows[pivot][j] {
      pivot += 1
    }
    if pivot == row_count {
      continue
    }
    let temp = rows[rank]
    rows[rank] = rows[pivot]
    rows[pivot] = temp
    for i = rank + 1; i < row_count; i = i + 1 {
      if !rows[i][j] {
        continue
      }
      for k = j; k < columns.length(); k = k + 1 {
        rows[i][k] = rows[i][k] != rows[rank][k]
      }
    }
    rank += 1
  }
  rank
}

///|
test "Betti numbers agree with independent dense rank oracle over 12 clouds" {
  for seed = 0; seed < 12; seed = seed + 1 {
    let points = Array::makei(6, fn(i) {
      [
        ((i * 7 + seed * 3) % 11).to_double() / 3.0,
        ((i * i + seed * 5) % 13).to_double() / 4.0,
      ]
    })
    let result = @moontopolens.analyze(
      @moontopolens.rips(points, threshold=5.0),
    )
    for step = 0; step <= 10; step = step + 1 {
      let scale = step.to_double() / 2.0
      let cells = result.filtration.cells
      let edges : Array[Array[Int]] = []
      let triangles : Array[Array[Int]] = []
      let mut vertices = 0
      for cell in cells {
        if cell.value > scale {
          continue
        }
        match cell.dimension {
          0 => vertices += 1
          1 => edges.push(cell.boundary)
          _ => triangles.push(cell.boundary)
        }
      }
      let r1 = dense_rank(edges, cells.length())
      let r2 = dense_rank(triangles, cells.length())
      assert_eq(@moontopolens.betti(result, 0, scale), vertices - r1)
      assert_eq(@moontopolens.betti(result, 1, scale), edges.length() - r1 - r2)
    }
    for interval in result.intervals {
      if interval.dimension != 1 {
        continue
      }
      let degree = Array::make(6, 0)
      for edge in @moontopolens.cycle_edges(result, interval) {
        degree[edge.0] += 1
        degree[edge.1] += 1
      }
      for d in degree {
        assert_eq(d % 2, 0)
      }
    }
  }
}

///|
test "translation and permutation preserve diagrams" {
  let a = @moontopolens.analyze(
    @moontopolens.rips(
      [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]],
      threshold=2.0,
    ),
  )
  let b = @moontopolens.analyze(
    @moontopolens.rips(
      [[11.0, 11.0], [10.0, 11.0], [10.0, 10.0], [11.0, 10.0]],
      threshold=2.0,
    ),
  )
  assert_true(@moontopolens.compare_analyses(a, b, dimension=0) is Some(0.0))
  assert_true(@moontopolens.compare_analyses(a, b, dimension=1) is Some(0.0))
}

// Exhaustive permutation oracle for the augmented finite-diagram assignment.

///|
fn exhaustive_cost(
  costs : Array[Array[Double]],
  row : Int,
  used : Array[Bool],
  current : Double,
  best : Double,
) -> Double {
  if row == costs.length() {
    return current
  }
  let mut result = best
  for col = 0; col < used.length(); col = col + 1 {
    if used[col] {
      continue
    }
    let candidate = if costs[row][col] > current {
      costs[row][col]
    } else {
      current
    }
    if candidate > result {
      continue
    }
    used[col] = true
    let found = exhaustive_cost(costs, row + 1, used, candidate, result)
    if found < result {
      result = found
    }
    used[col] = false
  }
  result
}

///|
test "bottleneck matching agrees with exhaustive assignments" {
  for seed = 0; seed < 16; seed = seed + 1 {
    let a = [(0.0, 2.0 + (seed % 3).to_double()), (1.0, 4.0)]
    let b = [((seed % 4).to_double(), 5.0), (2.0, 3.0 + (seed % 2).to_double())]
    let costs = Array::makei(4, fn(_) { Array::make(4, 0.0) })
    for i = 0; i < 2; i = i + 1 {
      for j = 0; j < 2; j = j + 1 {
        let dx = (a[i].0 - b[j].0).abs()
        let dy = (a[i].1 - b[j].1).abs()
        costs[i][j] = if dx > dy { dx } else { dy }
        costs[i][j + 2] = (a[i].1 - a[i].0) / 2.0
        costs[i + 2][j] = (b[j].1 - b[j].0) / 2.0
      }
    }
    let expected = exhaustive_cost(costs, 0, Array::make(4, false), 0.0, 100.0)
    assert_eq(@moontopolens.bottleneck(a, b), expected)
  }
}
