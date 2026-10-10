///|
test "series sweep returns aligned vectors and matching CSV rows" {
  let (report, summary, vectors) = @moontopolens.series_sweep(
    "{\"kind\":\"series_sweep\",\"threshold\":3,\"dimensions\":[2,3],\"lags\":[1,2],\"series\":[0,1,0,-1,0,1,0,-1,0,1,0,-1,0]}",
  )
  let data = report.stringify()
  assert_true(data.contains("\"case_count\":4"))
  assert_true(data.contains("\"h1_landscape_vector\""))
  assert_true(summary.contains("2,1,1,"))
  assert_true(summary.contains("3,2,1,"))
  assert_true(vectors.contains("lambda_3_sample_100"))
  assert_eq(summary.split("\n").length(), 6)
  assert_eq(vectors.split("\n").length(), 6)
}

///|
test "series sweep rejects invalid combinations and duplicate parameters" {
  let bad = [
    "{\"kind\":\"series_sweep\",\"threshold\":0,\"dimensions\":[2],\"lags\":[1],\"series\":[0,1]}",
    "{\"kind\":\"series_sweep\",\"threshold\":3,\"dimensions\":[2,2],\"lags\":[1],\"series\":[0,1,0,-1]}",
    "{\"kind\":\"series_sweep\",\"threshold\":3,\"dimensions\":[2,3,4,5],\"lags\":[1,2,3,4],\"series\":[0,1,0,-1]}",
    "{\"kind\":\"series_sweep\",\"threshold\":3,\"dimensions\":[2],\"lags\":[100],\"series\":[0,1,0,-1]}",
  ]
  for input in bad {
    let rejected = try {
      ignore(@moontopolens.series_sweep(input))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
