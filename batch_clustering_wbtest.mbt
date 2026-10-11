///|
test "single linkage retains a forest and suggests the largest gap" {
  let distances : Array[Array[Double?]] = [
    [Some(0.0), Some(0.1), Some(0.9), None],
    [Some(0.1), Some(0.0), Some(0.8), None],
    [Some(0.9), Some(0.8), Some(0.0), None],
    [None, None, None, Some(0.0)],
  ]
  let matrix : BatchDistanceMatrix = {
    names: ["a", "b", "c", "d"],
    kinds: ["rips", "rips", "rips", "rips"],
    cutoffs: [2.0, 2.0, 2.0, 2.0],
    h0: distances,
    h1: distances,
    conditions_aligned: Array::makei(4, fn(_) { Array::make(4, true) }),
  }
  let clustering = batch_clustering(matrix, 0)
  assert_eq(clustering.omitted_pairs, 3)
  assert_eq(clustering.merges.length(), 2)
  assert_eq(clustering.merges[0].members, ["a", "b"])
  assert_eq(clustering.merges[1].members, ["a", "b", "c"])
  assert_eq(clustering.roots, [5, 3])
  assert_eq(clustering.groups, [["a", "b", "c"], ["d"]])
  assert_eq(batch_clustering_suggested_cut(clustering), Some(0.45))
  assert_eq(batch_clustering_groups(clustering, 0.45), [
    ["a", "b"],
    ["c"],
    ["d"],
  ])
  assert_true(
    batch_clustering_json(clustering).stringify().contains("suggested_groups"),
  )
  assert_true(batch_clustering_svg(clustering).contains("<svg"))
}
