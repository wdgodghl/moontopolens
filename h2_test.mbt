///|
test "octahedron boundary has one finite H2 void" {
  let matrix = Array::makei(6, fn(i) {
    Array::makei(6, fn(j) {
      if i == j {
        0.0
      } else if (i == 0 && j == 1) ||
        (i == 1 && j == 0) ||
        (i == 2 && j == 3) ||
        (i == 3 && j == 2) ||
        (i == 4 && j == 5) ||
        (i == 5 && j == 4) {
        2.0
      } else {
        1.0
      }
    })
  })
  let result = @moontopolens.analyze(
    @moontopolens.rips_matrix(matrix, threshold=2.0, max_dimension=3),
    max_homology_dimension=2,
  )
  assert_eq(@moontopolens.betti(result, 2, 1.0), 1)
  assert_eq(@moontopolens.betti(result, 2, 2.0), 0)
  assert_eq(@moontopolens.diagram(result, 2), [(1.0, 2.0)])
  assert_true(@moontopolens.betti_csv(result).contains("scale,H0,H1,H2"))
}

///|
test "H2 JSON request builds tetrahedra and reports selected dimension" {
  let request = "{\"kind\":\"matrix\",\"threshold\":2,\"homology_dimension\":2,\"matrix\":[[0,2,1,1,1,1],[2,0,1,1,1,1],[1,1,0,2,1,1],[1,1,2,0,1,1],[1,1,1,1,0,2],[1,1,1,1,2,0]]}"
  let result = @moontopolens.analyze_json(request)
  let report = @moontopolens.report_json(result).stringify()
  assert_true(report.contains("\"homology_dimension\":2"))
  assert_true(report.contains("\"dimension\":3"))
  assert_eq(@moontopolens.betti(result, 2, 1.0), 1)
}

///|
test "H2 comparison and batch outputs distinguish unanalysed inputs" {
  let matrix_text = "[[0,2,1,1,1,1],[2,0,1,1,1,1],[1,1,0,2,1,1],[1,1,2,0,1,1],[1,1,1,1,0,2],[1,1,1,1,2,0]]"
  let full = @moontopolens.analyze_json(
    "{\"kind\":\"matrix\",\"threshold\":2,\"homology_dimension\":2,\"matrix\":" +
    matrix_text +
    "}",
  )
  let tight = @moontopolens.analyze_json(
    "{\"kind\":\"matrix\",\"threshold\":1.5,\"homology_dimension\":2,\"matrix\":" +
    matrix_text +
    "}",
  )
  let plain = @moontopolens.analyze_json(
    "{\"kind\":\"points\",\"threshold\":2,\"points\":[[0,0],[1,0],[1,1],[0,1]]}",
  )
  assert_eq(@moontopolens.compare_analyses(full, full, dimension=2), Some(0.0))
  assert_eq(@moontopolens.compare_analyses(full, tight, dimension=2), None)
  assert_true(
    @moontopolens.comparison_json(full, full)
    .stringify()
    .contains("\"h2_analyzed_on_both\":true"),
  )
  assert_true(@moontopolens.matching_csv(full, full).contains("\n2,"))
  assert_true(@moontopolens.comparison_html(full, full).contains("H2 空腔"))
  assert_true(
    @moontopolens.comparison_json(full, plain)
    .stringify()
    .contains("\"h2_analyzed_on_both\":false"),
  )
  assert_true(!@moontopolens.matching_csv(full, plain).contains("\n2,"))
  let plan = @moontopolens.parse_batch_manifest(
    "{\"all_pairs\":true,\"cases\":[{\"name\":\"full\",\"input\":\"a.json\"},{\"name\":\"copy\",\"input\":\"a.json\"},{\"name\":\"tight\",\"input\":\"b.json\"},{\"name\":\"plain\",\"input\":\"c.json\"}]}",
  )
  let matrix = @moontopolens.batch_distance_matrix(plan, [
    full, full, tight, plain,
  ])
  assert_eq(matrix.h2_analyzed, [true, true, true, false])
  assert_eq(matrix.h2[0][1], Some(0.0))
  assert_eq(matrix.h2[0][2], None)
  assert_eq(matrix.h2[0][3], None)
  assert_eq(matrix.h2[3][3], None)
  assert_true(
    @moontopolens.batch_matrix_json(matrix)
    .stringify()
    .contains("\"h2_analyzed\":[true,true,true,false]"),
  )
  assert_true(
    @moontopolens.batch_matrix_html(matrix).contains("H2 瓶颈距离"),
  )
  let cluster = @moontopolens.batch_clustering(matrix, 2)
  assert_eq(cluster.merges.length(), 1)
  assert_eq(cluster.groups.length(), 3)
}
