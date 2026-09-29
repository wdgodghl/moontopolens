///|
/// Build the 2-skeleton of a Vietoris–Rips filtration using diameter convention.
/// Edges appear at distance d; triangles at their maximum edge distance.
/// Two-dimensional cells suffice to compute H0 and H1, but not complete H2.
pub fn rips_matrix(
  matrix : Array[Array[Double]],
  threshold~ : Double,
  max_cells? : Int = 4000,
) -> Filtration raise TopologyError {
  validate_matrix(matrix)
  if !finite(threshold) || threshold < 0.0 || threshold > 1.0e100 {
    raise TopologyError("threshold must be finite, nonnegative and <= 1.0e100")
  }
  check_budget(matrix.length(), max_cells)
  let raw : Array[RawCell] = []
  let n = matrix.length()
  for i = 0; i < n; i = i + 1 {
    raw.push({
      key: vertex_key(i),
      dimension: 0,
      value: 0.0,
      faces: [],
      vertices: [i],
    })
  }
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      let d = matrix[i][j]
      if d <= threshold {
        check_budget(raw.length() + 1, max_cells)
        raw.push({
          key: edge_key(i, j),
          dimension: 1,
          value: d,
          faces: [vertex_key(i), vertex_key(j)],
          vertices: [i, j],
        })
      }
    }
  }
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      if matrix[i][j] > threshold {
        continue
      }
      for k = j + 1; k < n; k = k + 1 {
        let d = maximum(matrix[i][j], maximum(matrix[i][k], matrix[j][k]))
        if d <= threshold {
          check_budget(raw.length() + 1, max_cells)
          raw.push({
            key: triangle_key(i, j, k),
            dimension: 2,
            value: d,
            faces: [edge_key(i, j), edge_key(i, k), edge_key(j, k)],
            vertices: [i, j, k],
          })
        }
      }
    }
  }
  finalize(raw, n, "rips", threshold)
}

///|
/// Convenience point-cloud entry point.
pub fn rips(
  points : Array[Array[Double]],
  threshold~ : Double,
  max_cells? : Int = 4000,
) -> Filtration raise TopologyError {
  rips_matrix(distance_matrix(points), threshold~, max_cells~)
}
