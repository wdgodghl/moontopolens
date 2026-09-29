///|
test "exact events retain a loop missed by uniform sampling" {
  let result = @moontopolens.analyze(
    @moontopolens.cubical_grid(
      [[0.0, 0.004, 0.004], [0.004, 0.005, 0.004], [0.004, 0.004, 0.004]],
      threshold=1.0,
    ),
  )
  let events = @moontopolens.betti_events(result)
  assert_eq(events.length(), 4)
  assert_eq(events[1].scale, 0.004)
  assert_eq(events[1].h1, 1)
  assert_eq(events[2].scale, 0.005)
  assert_eq(events[2].h1, 0)
  assert_eq(events[3].scale, 1.0)
  assert_eq(@moontopolens.betti_curve(result, dimension=1, [0.0, 0.01, 1.0]), [
    0, 0, 0,
  ])
  for event in events {
    assert_eq(event.h0, @moontopolens.betti(result, 0, event.scale))
    assert_eq(event.h1, @moontopolens.betti(result, 1, event.scale))
  }
  assert_true(@moontopolens.betti_events_csv(result).contains("0.005,1,0\n"))
}

///|
test "event sweep handles simultaneous deaths censored classes and empty input" {
  let result = @moontopolens.analyze(
    @moontopolens.rips([[0.0], [1.0], [2.0]], threshold=1.0),
  )
  let events = @moontopolens.betti_events(result)
  assert_eq(events.length(), 2)
  assert_eq(events[0].h0, 3)
  assert_eq(events[1].h0, 1)
  let empty = @moontopolens.analyze(
    @moontopolens.cubical_grid([], threshold=-1.0),
  )
  let empty_events = @moontopolens.betti_events(empty)
  assert_eq(empty_events.length(), 1)
  assert_eq(empty_events[0].scale, -1.0)
  assert_eq(empty_events[0].h0, 0)
}

///|
test "components retain input IDs and merge at exactly the edge scale" {
  let result = @moontopolens.analyze(
    @moontopolens.rips([[0.0], [1.0], [4.0]], threshold=4.0),
  )
  assert_eq(@moontopolens.connected_components(result, -1.0), [])
  assert_eq(@moontopolens.connected_components(result, 0.5), [[0], [1], [2]])
  assert_eq(@moontopolens.connected_components(result, 1.0), [[0, 1], [2]])
  assert_eq(@moontopolens.connected_components(result, 3.0), [[0, 1, 2]])
  assert_true(
    @moontopolens.snapshot_json(result, 1.0)
    is { "h0": 2, "h1": 0, "active_cells_by_dimension": [3, 1, 0], .. },
  )
  let invalid = try {
    ignore(@moontopolens.snapshot_json(result, 4.01))
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
test "components handle grid gaps negative births and matrix data" {
  let grid = @moontopolens.analyze(
    @moontopolens.cubical_grid(
      [[-2.0, 1.0, -2.0], [1.0, 1.0, 1.0]],
      threshold=1.0,
    ),
  )
  assert_eq(@moontopolens.connected_components(grid, -2.0), [[0], [2]])
  for event in @moontopolens.betti_events(grid) {
    assert_eq(
      @moontopolens.connected_components(grid, event.scale).length(),
      event.h0,
    )
  }
  let matrix = @moontopolens.analyze(
    @moontopolens.rips_matrix(
      [[0.0, 1.0, 4.0], [1.0, 0.0, 3.0], [4.0, 3.0, 0.0]],
      threshold=4.0,
    ),
  )
  assert_eq(@moontopolens.connected_components(matrix, 1.0), [[0, 1], [2]])
}

///|
test "landscape produces raw tent heights and zero padding" {
  let result = @moontopolens.analyze(
    @moontopolens.cubical_grid(
      [[0.0, 0.0, 0.0], [0.0, 4.0, 0.0], [0.0, 0.0, 0.0]],
      threshold=4.0,
    ),
  )
  let landscape = @moontopolens.persistence_landscape(
    result,
    dimension=1,
    start=0.0,
    end=4.0,
    samples=5,
    layers=2,
  )
  assert_eq(landscape, [[0.0, 1.0, 2.0, 1.0, 0.0], [0.0, 0.0, 0.0, 0.0, 0.0]])
  assert_true(
    @moontopolens.landscape_json(
      result,
      dimension=1,
      start=0.0,
      end=4.0,
      samples=5,
      layers=2,
    )
    is {
      "vector": [0, 1, 2, 1, 0, 0, 0, 0, 0, 0],
      "normalization": "none; raw tent heights",
      ..
    },
  )
  assert_true(
    @moontopolens.landscape_csv(
      result,
      dimension=1,
      start=0.0,
      end=4.0,
      samples=5,
      layers=2,
    ).contains("2,2,0\n"),
  )
}

///|
test "landscape ranks overlapping tents and excludes censored classes" {
  let result = @moontopolens.analyze(
    @moontopolens.cubical_grid(
      [
        [0.0, 0.0, 0.0, 0.0, 0.0],
        [0.0, 4.0, 0.0, 2.0, 0.0],
        [0.0, 0.0, 0.0, 0.0, 0.0],
      ],
      threshold=4.0,
    ),
  )
  assert_eq(
    @moontopolens.persistence_landscape(
      result,
      dimension=1,
      start=0.0,
      end=4.0,
      samples=5,
      layers=2,
    ),
    [[0.0, 1.0, 2.0, 1.0, 0.0], [0.0, 1.0, 0.0, 0.0, 0.0]],
  )
  let censored = @moontopolens.analyze(
    @moontopolens.cubical_grid(
      [[0.0, 0.0, 0.0], [0.0, 4.0, 0.0], [0.0, 0.0, 0.0]],
      threshold=1.0,
    ),
  )
  assert_true(
    @moontopolens.landscape_json(
      censored,
      dimension=1,
      start=0.0,
      end=4.0,
      samples=3,
      layers=1,
    )
    is { "censored_intervals_excluded": 1, "vector": [0, 0, 0], .. },
  )
}

///|
test "landscape rejects invalid dimensions ranges and budgets" {
  let result = @moontopolens.analyze(@moontopolens.rips([[0.0]], threshold=1.0))
  for
    args in [
      (2, 0.0, 1.0, 3, 1),
      (0, 1.0, 1.0, 3, 1),
      (0, 0.0, 1.0, 1, 1),
      (0, 0.0, 1.0, 3, 17),
    ] {
    let invalid = try {
      ignore(
        @moontopolens.persistence_landscape(
          result,
          dimension=args.0,
          start=args.1,
          end=args.2,
          samples=args.3,
          layers=args.4,
        ),
      )
      false
    } catch {
      _ => true
    }
    assert_true(invalid)
  }
}
