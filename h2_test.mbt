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
