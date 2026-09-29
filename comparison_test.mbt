///|
test "optimal matching accounts for each interval and attains the distance" {
  for trial = 0; trial < 12; trial = trial + 1 {
    let a = @moontopolens.analyze(
      @moontopolens.rips(
        @moontopolens.circle_points(6, 0.5 + trial.to_double() * 0.03),
        threshold=3.0,
      ),
    )
    let b = @moontopolens.analyze(
      @moontopolens.rips(
        @moontopolens.circle_points(5, 0.7 + trial.to_double() * 0.02),
        threshold=3.0,
      ),
    )
    for dimension = 0; dimension < 2; dimension = dimension + 1 {
      let matches = @moontopolens.interval_matching(a, b, dimension~)
      let left : Array[Int] = []
      let right : Array[Int] = []
      let mut highest = 0.0
      for pair in matches {
        if pair.left is Some(i) {
          left.push(i)
          assert_eq(a.intervals[i].dimension, dimension)
        }
        if pair.right is Some(i) {
          right.push(i)
          assert_eq(b.intervals[i].dimension, dimension)
        }
        let cost = match pair.cost {
          Some(c) => c
          None => -1.0
        }
        assert_true(cost >= 0.0)
        if cost > highest {
          highest = cost
        }
        match (pair.left, pair.right) {
          (Some(i), Some(j)) => {
            let ai = a.intervals[i]
            let bj = b.intervals[j]
            let birth = (ai.birth - bj.birth).abs()
            match (ai.death, bj.death) {
              (Some(ad), Some(bd)) => {
                let death = (ad - bd).abs()
                assert_eq(cost, if birth > death { birth } else { death })
                assert_eq(pair.kind, "finite")
              }
              (None, None) => {
                assert_eq(cost, birth)
                assert_eq(pair.kind, "censored")
              }
              _ => assert_true(false)
            }
          }
          (Some(i), None) => {
            let death = a.intervals[i].death.unwrap()
            assert_eq(cost, (death - a.intervals[i].birth) / 2.0)
            assert_eq(pair.kind, "diagonal")
          }
          (None, Some(j)) => {
            let death = b.intervals[j].death.unwrap()
            assert_eq(cost, (death - b.intervals[j].birth) / 2.0)
            assert_eq(pair.kind, "diagonal")
          }
          _ => assert_true(false)
        }
      }
      left.sort()
      right.sort()
      let expected_left : Array[Int] = []
      let expected_right : Array[Int] = []
      for i = 0; i < a.intervals.length(); i = i + 1 {
        if a.intervals[i].dimension == dimension {
          expected_left.push(i)
        }
      }
      for i = 0; i < b.intervals.length(); i = i + 1 {
        if b.intervals[i].dimension == dimension {
          expected_right.push(i)
        }
      }
      assert_eq(left, expected_left)
      assert_eq(right, expected_right)
      assert_eq(@moontopolens.compare_analyses(a, b, dimension~), Some(highest))
    }
  }
}

///|
test "unequal censored counts are not falsely assigned finite costs" {
  let a = @moontopolens.analyze(
    @moontopolens.rips([[0.0], [1.0], [2.0]], threshold=0.0),
  )
  let b = @moontopolens.analyze(@moontopolens.rips([[0.0]], threshold=0.0))
  let matches = @moontopolens.interval_matching(a, b, dimension=0)
  assert_eq(matches.length(), 4)
  for pair in matches {
    assert_eq(pair.kind, "unmatched_censored")
    assert_eq(pair.cost, None)
  }
  assert_true(
    @moontopolens.comparison_json(a, b)
    is {
      "distances": [{ "bottleneck": Null, "finite_distance": false, .. }, _],
      ..
    },
  )
  assert_true(
    @moontopolens.matching_csv(a, b).contains("unmatched_censored,\n"),
  )
}

///|
test "empty comparisons and invalid dimension behave consistently" {
  let empty = @moontopolens.analyze(
    @moontopolens.cubical_grid([], threshold=0.0),
  )
  assert_eq(
    @moontopolens.interval_matching(empty, empty, dimension=0).length(),
    0,
  )
  assert_eq(
    @moontopolens.compare_analyses(empty, empty, dimension=0),
    Some(0.0),
  )
  let invalid = try {
    ignore(@moontopolens.interval_matching(empty, empty, dimension=2))
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
test "scale SVG colors components and highlights only a live H1 representative" {
  let result = @moontopolens.analyze(
    @moontopolens.rips(
      [[0.0, 0.0], [1.0, 0.0], [1.0, 1.0], [0.0, 1.0]],
      threshold=2.0,
    ),
  )
  let separated = @moontopolens.scale_svg(result, scale=0.0)
  assert_true(separated.contains("H0=4"))
  assert_true(separated.contains("fill=\"#a78bfa\""))
  let mut loop_index = -1
  for i = 0; i < result.intervals.length(); i = i + 1 {
    if result.intervals[i].dimension == 1 {
      loop_index = i
    }
  }
  let highlighted = @moontopolens.scale_svg(
    result,
    scale=1.0,
    interval=Some(loop_index),
  )
  assert_true(highlighted.contains("stroke=\"#fb923c\""))
  assert_true(highlighted.contains("H0=1 | H1=1"))
  for args in [(0.0, loop_index), (2.0, loop_index), (1.0, -1), (1.0, 0)] {
    let invalid = try {
      ignore(
        @moontopolens.scale_svg(result, scale=args.0, interval=Some(args.1)),
      )
      false
    } catch {
      _ => true
    }
    assert_true(invalid)
  }
}

///|
test "scale SVG handles empty slices coincident coordinates and unavailable geometry" {
  let one = @moontopolens.analyze(
    @moontopolens.rips([[0.0, 0.0]], threshold=1.0),
  )
  assert_true(@moontopolens.scale_svg(one, scale=-1.0).contains("H0=0 | H1=0"))
  assert_true(@moontopolens.scale_svg(one, scale=0.0).contains("cx=\"400\""))
  let matrix = @moontopolens.analyze(
    @moontopolens.rips_matrix([[0.0]], threshold=0.0),
  )
  let invalid = try {
    ignore(@moontopolens.scale_svg(matrix, scale=0.0))
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}
