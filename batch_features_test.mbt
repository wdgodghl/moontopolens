///|
test "common feature grid preserves duplicate samples and rejects invalid ranges" {
  let result = @moontopolens.analyze_json(
    "{\"kind\":\"points\",\"threshold\":2,\"points\":[[0,0],[1,0],[1,1],[0,1]]}",
  )
  let (info, csv) = @moontopolens.batch_features(
    [result, result],
    ["a", "b"],
    dimension=1,
    start=0.0,
    end=2.0,
    samples=3,
    layers=1,
  )
  assert_true(info.stringify().contains("complex_kinds_and_cutoffs_equal"))
  let lines = csv.split("\n").to_array()
  assert_eq(lines.length(), 4)
  assert_eq(
    lines[1].to_owned()[1:].to_owned(),
    lines[2].to_owned()[1:].to_owned(),
  )
  for names in [["a", "a"], ["a"], ["=formula", "b"]] {
    let rejected = try {
      ignore(
        @moontopolens.batch_features(
          [result, result],
          names,
          dimension=1,
          start=0.0,
          end=2.0,
        ),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  for dim in [-1, 2, 3] {
    let rejected = try {
      ignore(
        @moontopolens.batch_features(
          [result],
          ["a"],
          dimension=dim,
          start=0.0,
          end=2.0,
        ),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
  for end in [0.0, 3.0] {
    let rejected = try {
      ignore(
        @moontopolens.batch_features(
          [result],
          ["a"],
          dimension=1,
          start=0.0,
          end~,
        ),
      )
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}

///|
test "three dimensional coordinates and source windows are retained" {
  let result = @moontopolens.analyze_json(
    "{\"kind\":\"points\",\"threshold\":2,\"points\":[[0,0,1,3],[1,0,2,3]]}",
  )
  assert_eq(result.filtration.positions[0], [0.0, 0.0, 1.0, 3.0])
  let info = @moontopolens.csv_series_preparation_json(
    "v\n0\n1\n2\n3\n4",
    dimension=2,
    lag=2,
    stride=2,
  )
  assert_true(info.stringify().contains("window_data_row_indices"))
}
