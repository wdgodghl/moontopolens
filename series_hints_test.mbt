///|
test "alternating series yields a first-lag correlation hint" {
  let (report, csv) = @moontopolens.series_lag_hints(
    "{\"kind\":\"series_hints\",\"series\":[0,1,0,1,0,1,0,1],\"bins\":2}",
  )
  let output = report.stringify()
  assert_true(output.contains("\"sample_count\":8"))
  assert_true(output.contains("\"max_lag\":4"))
  assert_true(
    output.contains("\"method\":\"first autocorrelation at or below 1/e\""),
  )
  assert_true(csv.contains("1,7,"))
  assert_eq(csv.split("\n").length(), 6)
}

///|
test "lag hints reject constant, insufficient and out-of-range input" {
  let invalid = [
    "{\"kind\":\"series_hints\",\"series\":[1,1,1,1,1,1,1,1]}", "{\"kind\":\"series_hints\",\"series\":[0,1,0,1,0,1,0]}",
    "{\"kind\":\"series_hints\",\"series\":[0,1,0,1,0,1,0,1],\"max_lag\":5}", "{\"kind\":\"series_hints\",\"series\":[0,1,0,1,0,1,0,1],\"bins\":33}",
  ]
  for input in invalid {
    let rejected = try {
      ignore(@moontopolens.series_lag_hints(input))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
