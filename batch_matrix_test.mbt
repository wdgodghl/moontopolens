///|
test "batch matrix is symmetric, diagonal zero and flags mismatched conditions" {
  let plan = @moontopolens.parse_batch_manifest(
    "{\"all_pairs\":true,\"cases\":[{\"name\":\"square\",\"input\":\"a.json\"},{\"name\":\"copy\",\"input\":\"b.json\"},{\"name\":\"clusters\",\"input\":\"c.json\"}]}",
  )
  let square = @moontopolens.analyze_json(
    "{\"kind\":\"points\",\"threshold\":2,\"points\":[[0,0],[1,0],[1,1],[0,1]]}",
  )
  let clusters = @moontopolens.analyze_json(
    "{\"kind\":\"points\",\"threshold\":0.5,\"points\":[[0,0],[0,0.2],[3,0],[3,0.2]]}",
  )
  let matrix = @moontopolens.batch_distance_matrix(plan, [
    square, square, clusters,
  ])
  assert_eq(matrix.names, ["square", "copy", "clusters"])
  assert_eq(matrix.h0[0][0], Some(0.0))
  assert_eq(matrix.h1[0][1], Some(0.0))
  assert_eq(matrix.h0[0][2], None)
  assert_eq(matrix.h0[2][0], None)
  assert_eq(matrix.h1[0][2], matrix.h1[2][0])
  assert_true(matrix.conditions_aligned[0][1])
  assert_true(!matrix.conditions_aligned[0][2])
  assert_eq(
    @moontopolens.batch_matrix_csv(matrix, 0),
    "case,square,copy,clusters\nsquare,0,0,\ncopy,0,0,\nclusters,,,0\n",
  )
}

///|
test "batch matrix validates dimensions and case count" {
  let plan = @moontopolens.parse_batch_manifest(
    "{\"cases\":[{\"name\":\"a\",\"input\":\"a.json\"}]}",
  )
  let failed = try {
    ignore(@moontopolens.batch_distance_matrix(plan, []))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}
