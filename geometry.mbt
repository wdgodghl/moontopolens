/// Validate coordinates and compute Euclidean distances in any dimension <= 32.
/// Limits avoid overflow and accidental quadratic allocation on untrusted input.
pub fn distance_matrix(points : Array[Array[Double]]) -> Array[Array[Double]] raise TopologyError {
  let n = points.length()
  if n > 128 { raise TopologyError("at most 128 points are supported") }
  if n == 0 { return [] }
  let dimension = points[0].length()
  if dimension < 1 || dimension > 32 {
    raise TopologyError("point dimension must be between 1 and 32")
  }
  for point in points {
    if point.length() != dimension { raise TopologyError("inconsistent point dimensions") }
    for x in point {
      if !finite(x) || x.abs() > 1.0e100 {
        raise TopologyError("coordinates must be finite with absolute value <= 1.0e100")
      }
    }
  }
  let matrix = Array::makei(n, fn(_) { Array::make(n, 0.0) })
  for i = 0; i < n; i = i + 1 {
    for j = i + 1; j < n; j = j + 1 {
      let mut d = 0.0
      for k = 0; k < dimension; k = k + 1 {
        d = @math.hypot(d, points[i][k] - points[j][k])
      }
      matrix[i][j] = d
      matrix[j][i] = d
    }
  }
  matrix
}

/// Symmetric nonnegative dissimilarities are accepted without a triangle axiom.
/// Exact symmetry is required, rather than silently changing user data.
pub fn validate_matrix(matrix : Array[Array[Double]]) -> Unit raise TopologyError {
  let n = matrix.length()
  if n > 128 { raise TopologyError("at most 128 matrix rows are supported") }
  for row in matrix {
    if row.length() != n { raise TopologyError("distance matrix must be square") }
  }
  for i = 0; i < n; i = i + 1 {
    if matrix[i][i] != 0.0 { raise TopologyError("matrix diagonal must be zero") }
    for j = 0; j < n; j = j + 1 {
      let d = matrix[i][j]
      if !finite(d) || d < 0.0 || d > 1.0e100 {
        raise TopologyError("distances must be finite, nonnegative and <= 1.0e100")
      }
      if d != matrix[j][i] { raise TopologyError("distance matrix must be symmetric") }
    }
  }
}

/// Generate a deterministic 2D circle for teaching and reproducible examples.
pub fn circle_points(count : Int, radius : Double) -> Array[Array[Double]] raise TopologyError {
  if count < 3 || count > 128 || !finite(radius) || radius <= 0.0 || radius > 1.0e100 {
    raise TopologyError("circle requires 3..128 points and positive finite radius <= 1.0e100")
  }
  Array::makei(count, fn(i) {
    let angle = 2.0 * @math.PI * i.to_double() / count.to_double()
    [radius * @math.cos(angle), radius * @math.sin(angle)]
  })
}

