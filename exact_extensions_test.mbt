///|
test "sparse Rips equals dense cells and intervals in H0 H1 H2" {
  for
    points in [
      [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]],
      [[3.0], [2.0], [2.0], [0.0]],
      [
        [0.0, 0.0, 1.0],
        [0.0, 0.0, -1.0],
        [1.0, 0.0, 0.0],
        [-1.0, 0.0, 0.0],
        [0.0, 1.0, 0.0],
        [0.0, -1.0, 0.0],
      ],
    ] {
    for threshold in [0.0, 1.0, 1.5, 2.0] {
      for dimension in [2, 3] {
        let dense = @moontopolens.analyze(
          @moontopolens.rips(points, threshold~, max_dimension=dimension),
          max_homology_dimension=dimension - 1,
        )
        let sparse = @moontopolens.analyze(
          @moontopolens.rips_sparse(points, threshold~, max_dimension=dimension),
          max_homology_dimension=dimension - 1,
        )
        assert_eq(
          @moontopolens.report_json(dense).stringify(),
          @moontopolens.report_json(sparse).stringify(),
        )
      }
    }
  }
}

///|
test "large exact line is connected without subsampling" {
  let points = Array::makei(2048, fn(i) { [i.to_double()] })
  let result = @moontopolens.analyze(
    @moontopolens.rips_sparse(points, threshold=1.0),
    representatives=false,
  )
  assert_eq(result.filtration.vertex_count, 2048)
  assert_eq(result.filtration.cells.length(), 4095)
  assert_eq(@moontopolens.betti(result, 0, 1.0), 1)
  assert_eq(@moontopolens.betti(result, 1, 1.0), 0)
  for rows in [[[0.0], [1.0, 2.0]], [[]]] {
    let rejected = try {
      ignore(@moontopolens.rips_sparse(rows, threshold=1.0))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  let rejected = try {
    ignore(
      @moontopolens.rips_sparse(
        Array::makei(40, fn(_) { [0.0] }),
        threshold=1.0,
        max_cells=50,
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "exact shortest H1 preserves an unfilled square" {
  let result = @moontopolens.analyze_json(
    "{\"kind\":\"points\",\"threshold\":2,\"points\":[[0,0],[1,0],[1,1],[0,1]]}",
  )
  let mut index = -1
  for i, interval in result.intervals {
    if interval.dimension == 1 {
      index = i
    }
  }
  assert_eq(@moontopolens.shortest_representative(result, index).length(), 4)
  assert_true(
    @moontopolens.shortest_representative_json(result, index)
    .stringify()
    .contains("\"optimal\":true"),
  )
  for invalid in [-1, 0, 1000] {
    let rejected = try {
      ignore(@moontopolens.shortest_representative(result, invalid))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "shortest solver rejects absent chains and unsupported dimensions" {
  let full = @moontopolens.analyze_json(
    "{\"kind\":\"grid\",\"threshold\":1,\"grid\":[[0,0,0],[0,1,0],[0,0,0]]}",
  )
  let lean = @moontopolens.analyze_json(
    "{\"kind\":\"grid\",\"threshold\":1,\"grid\":[[0,0,0],[0,1,0],[0,0,0]]}",
    representatives=false,
  )
  let mut index = -1
  for i, interval in full.intervals {
    if interval.dimension == 1 {
      index = i
    }
  }
  let rejected = try {
    ignore(@moontopolens.shortest_representative(lean, index))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(@moontopolens.shortest_representative(full, index).length(), 8)
}
