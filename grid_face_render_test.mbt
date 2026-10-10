///|
test "grid snapshot draws only faces active at the selected scale" {
  let analysis = @moontopolens.analyze_json(
    "{\"kind\":\"grid\",\"threshold\":1,\"grid\":[[0,0,0],[0,1,0],[0,0,0]]}",
  )
  let open = @moontopolens.scale_svg(analysis, scale=0.0)
  let filled = @moontopolens.scale_svg(analysis, scale=1.0)
  assert_eq(open.split("<polygon").length(), 1)
  assert_eq(filled.split("<polygon").length(), 5)
  assert_true(filled.contains("fill=\"#2dd4bf\""))
  assert_true(filled.contains("data-cell-index="))
}

///|
test "Rips snapshot does not render projected triangles as filled faces" {
  let analysis = @moontopolens.analyze_json(
    "{\"kind\":\"points\",\"threshold\":2,\"points\":[[0,0],[1,0],[1,1],[0,1]]}",
  )
  let svg = @moontopolens.scale_svg(analysis, scale=2.0)
  assert_eq(svg.split("<polygon").length(), 1)
}
