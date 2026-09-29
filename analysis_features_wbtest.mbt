///|
test "zero length events cancel and nonfinite query scales are rejected" {
  let result = analyze(rips([[0.0], [0.0]], threshold=0.0), include_zero=true)
  let events = betti_events(result)
  assert_eq(events.length(), 1)
  assert_eq(events[0].h0, 1)
  let invalid = try {
    ignore(snapshot_json(result, 0.0 / 0.0))
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
  let invalid_range = try {
    ignore(persistence_landscape(result, dimension=0, start=0.0, end=1.0 / 0.0))
    false
  } catch {
    _ => true
  }
  assert_true(invalid_range)
}

///|
test "landscape insertion budget is enforced before allocating output" {
  let f = rips([[0.0]], threshold=1.0)
  let intervals = Array::make(126, {
    dimension: 1,
    birth: 0.0,
    death: Some(1.0),
    birth_cell: 0,
    death_cell: Some(0),
    representative: [],
  })
  let result : Analysis = { filtration: f, intervals, column_additions: 0, }
  let invalid = try {
    ignore(
      persistence_landscape(
        result,
        dimension=1,
        start=0.0,
        end=1.0,
        samples=1001,
        layers=16,
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
test "components reject unsupported custom vertex encodings" {
  let f = rips([[0.0]], threshold=1.0)
  f.cells[0] = {
    key: "custom",
    dimension: 0,
    value: 0.0,
    boundary: [],
    vertices: [],
  }
  let invalid = try {
    ignore(connected_components(analyze(f), 0.0))
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}
