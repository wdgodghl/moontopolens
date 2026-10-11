///|
test "zero coordinate jitter reproduces the same H1 feature" {
  let report = @moontopolens.point_stability_json(
    "{\"kind\":\"points\",\"threshold\":2,\"points\":[[0,0],[1,0],[1,1],[0,1]]}",
    0.0,
    trials=3,
  ).stringify()
  assert_true(report.contains("\"baseline_h1_count\":1"))
  assert_true(report.contains("\"retained_trials\":3"))
  assert_true(report.contains("\"h1_bottleneck\":0"))
}

///|
test "stability rejects unsupported or unbounded studies" {
  let square = "{\"kind\":\"points\",\"threshold\":2,\"points\":[[0,0],[1,0],[1,1],[0,1]]}"
  let invalid_epsilon = try {
    ignore(@moontopolens.point_stability_json(square, -0.1))
    false
  } catch {
    _ => true
  }
  let invalid_kind = try {
    ignore(
      @moontopolens.point_stability_json(
        "{\"kind\":\"grid\",\"threshold\":1,\"grid\":[[0,0],[0,1]]}", 0.1,
      ),
    )
    false
  } catch {
    _ => true
  }
  assert_true(invalid_epsilon && invalid_kind)
}
