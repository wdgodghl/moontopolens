///|
test "interval-only reduction preserves H0 H1 H2 pairs and column work" {
  for
    request in [
      "{\"kind\":\"points\",\"threshold\":2,\"points\":[[0,0],[1,0],[1,1],[0,1]]}",
      "{\"kind\":\"grid\",\"threshold\":1,\"grid\":[[0,0,0],[0,1,0],[0,0,0]]}", "{\"kind\":\"volume\",\"threshold\":1,\"volume\":[[[0,0,0],[0,0,0],[0,0,0]],[[0,0,0],[0,1,0],[0,0,0]],[[0,0,0],[0,0,0],[0,0,0]]]}",
    ] {
    let full = @moontopolens.analyze_json(request)
    let lean = @moontopolens.analyze_json(request, representatives=false)
    assert_true(full.representatives_computed)
    assert_eq(lean.representatives_computed, false)
    assert_eq(full.column_additions, lean.column_additions)
    assert_true(lean.reduction_entries < full.reduction_entries)
    assert_eq(full.intervals.length(), lean.intervals.length())
    for index, interval in lean.intervals {
      let expected = full.intervals[index]
      assert_eq(
        (
          interval.dimension,
          interval.birth,
          interval.death,
          interval.birth_cell,
          interval.death_cell,
        ),
        (
          expected.dimension,
          expected.birth,
          expected.death,
          expected.birth_cell,
          expected.death_cell,
        ),
      )
      assert_eq(interval.representative, [])
    }
    for dimension = 0
        dimension <= full.homology_dimension
        dimension = dimension + 1 {
      assert_eq(
        @moontopolens.diagram(full, dimension),
        @moontopolens.diagram(lean, dimension),
      )
    }
  }
}

///|
test "interval-only request flag is strict and representative decoding rejects" {
  let lean = @moontopolens.analyze_json(
    "{\"kind\":\"points\",\"threshold\":2,\"representatives\":false,\"points\":[[0,0],[1,0],[1,1],[0,1]]}",
  )
  assert_eq(lean.representatives_computed, false)
  for interval in lean.intervals {
    if interval.dimension == 1 {
      let rejected = try {
        ignore(@moontopolens.cycle_edges(lean, interval))
        false
      } catch {
        _ => true
      }
      assert_true(rejected)
    }
  }
  let rejected = try {
    ignore(
      @moontopolens.analyze_json(
        "{\"kind\":\"points\",\"threshold\":2,\"representatives\":0,\"points\":[]}",
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
