///|
test "finite H1 recommendation lies within its interval" {
  let analysis = @moontopolens.analyze_json(
    "{\"kind\":\"grid\",\"threshold\":1,\"grid\":[[0,0,0],[0,1,0],[0,0,0]]}",
  )
  let suggestions = @moontopolens.recommend_scales(analysis)
  assert_eq(suggestions.length(), 2)
  let first = suggestions[0]
  assert_eq(first.reason, "h1_finite")
  assert_eq(first.scale, 0.5)
  assert_eq(first.observed_lifetime, Some(1.0))
  assert_true(!first.censored)
  assert_eq(@moontopolens.betti(analysis, 1, first.scale), 1)
  assert_eq(suggestions[1].reason, "final_cutoff")
  assert_eq(suggestions[1].scale, 1.0)
  assert_eq(@moontopolens.betti(analysis, 1, suggestions[1].scale), 0)
}

///|
test "censored H1 recommendation labels the observed lower bound" {
  let analysis = @moontopolens.analyze_json(
    "{\"kind\":\"points\",\"threshold\":1,\"points\":[[0,0],[1,0],[1,1],[0,1]]}",
  )
  let suggestions = @moontopolens.recommend_scales(analysis)
  assert_eq(suggestions[0].reason, "h1_alive_at_cutoff")
  assert_true(suggestions[0].censored)
  assert_eq(suggestions[0].scale, 1.0)
  assert_eq(suggestions[0].observed_lifetime, Some(0.0))
  assert_eq(@moontopolens.betti(analysis, 1, suggestions[0].scale), 1)
}

///|
test "no H1 falls back to final cutoff and validates suggestion limit" {
  let analysis = @moontopolens.analyze_json(
    "{\"kind\":\"grid\",\"threshold\":1,\"grid\":[[0]]}",
  )
  let suggestions = @moontopolens.recommend_scales(analysis)
  assert_eq(suggestions.length(), 1)
  assert_eq(suggestions[0].interval_index, None)
  assert_eq(suggestions[0].reason, "final_cutoff")
  let invalid = try {
    ignore(@moontopolens.recommend_scales(analysis, max_loops=0))
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
test "cluster data receives an exact pre-merge H0 viewing scale" {
  let analysis = @moontopolens.analyze_json(
    "{\"kind\":\"points\",\"threshold\":0.5,\"points\":[[0,0],[0,0.2],[3,0],[3,0.2]]}",
  )
  let suggestions = @moontopolens.recommend_scales(analysis)
  assert_eq(suggestions.length(), 2)
  assert_eq(suggestions[0].reason, "h0_before_merges")
  assert_eq(suggestions[0].scale, 0.0)
  assert_eq(@moontopolens.betti(analysis, 0, suggestions[0].scale), 4)
  assert_eq(@moontopolens.betti(analysis, 0, suggestions[1].scale), 2)
}
