///|
/// Finite points (birth, death) of one dimension in a persistence diagram.
pub fn diagram(
  analysis : Analysis,
  dimension : Int,
) -> Array[(Double, Double)] raise TopologyError {
  if dimension < 0 || dimension > 1 {
    raise TopologyError("diagram dimension must be 0 or 1")
  }
  let result : Array[(Double, Double)] = []
  for interval in analysis.intervals {
    if interval.dimension == dimension {
      match interval.death {
        Some(d) => result.push((interval.birth, d))
        None => ()
      }
    }
  }
  result
}

///|
fn validate_diagram(
  points : Array[(Double, Double)],
) -> Unit raise TopologyError {
  if points.length() > 64 {
    raise TopologyError(
      "bottleneck comparison supports at most 64 finite intervals per diagram",
    )
  }
  for point in points {
    if !finite(point.0) ||
      !finite(point.1) ||
      point.0.abs() > 1.0e100 ||
      point.1.abs() > 1.0e100 ||
      point.1 < point.0 {
      raise TopologyError(
        "diagram points must have bounded finite birth <= death",
      )
    }
  }
}

///|
fn match_augment(
  row : Int,
  costs : Array[Array[Double]],
  epsilon : Double,
  visited : Array[Bool],
  owners : Array[Int],
) -> Bool {
  for col = 0; col < owners.length(); col = col + 1 {
    if visited[col] || costs[row][col] > epsilon {
      continue
    }
    visited[col] = true
    if owners[col] == -1 ||
      match_augment(owners[col], costs, epsilon, visited, owners) {
      owners[col] = row
      return true
    }
  }
  false
}

///|
fn perfect_matching(costs : Array[Array[Double]], epsilon : Double) -> Bool {
  let n = costs.length()
  let owners = Array::make(n, -1)
  for row = 0; row < n; row = row + 1 {
    if !match_augment(row, costs, epsilon, Array::make(n, false), owners) {
      return false
    }
  }
  true
}

///|
/// Exact finite-diagram bottleneck distance with diagonal matching, L-infinity.
/// Binary-searches the candidate edge costs using bipartite perfect matching.
pub fn bottleneck(
  a : Array[(Double, Double)],
  b : Array[(Double, Double)],
) -> Double raise TopologyError {
  validate_diagram(a)
  validate_diagram(b)
  let m = a.length()
  let n = b.length()
  let size = m + n
  if size == 0 {
    return 0.0
  }
  let costs = Array::makei(size, fn(_) { Array::make(size, 0.0) })
  let candidates : Array[Double] = [0.0]
  for i = 0; i < m; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      let d = maximum((a[i].0 - b[j].0).abs(), (a[i].1 - b[j].1).abs())
      costs[i][j] = d
      candidates.push(d)
    }
    let diagonal = (a[i].1 - a[i].0) / 2.0
    for j = n; j < size; j = j + 1 {
      costs[i][j] = diagonal
    }
    candidates.push(diagonal)
  }
  for i = m; i < size; i = i + 1 {
    for j = 0; j < n; j = j + 1 {
      costs[i][j] = (b[j].1 - b[j].0) / 2.0
    }
  }
  for point in b {
    candidates.push((point.1 - point.0) / 2.0)
  }
  candidates.sort()
  let mut low = 0
  let mut high = candidates.length() - 1
  while low < high {
    let mid = low + (high - low) / 2
    if perfect_matching(costs, candidates[mid]) {
      high = mid
    } else {
      low = mid + 1
    }
  }
  candidates[low]
}

///|
/// Compare complete interval collections of one dimension, including essentials.
/// Essential intervals only match essential intervals; unequal counts => None.
/// Under a finite cutoff, essential here means alive at that cutoff.
pub fn compare_analyses(
  a : Analysis,
  b : Analysis,
  dimension~ : Int,
) -> Double? raise TopologyError {
  let da = diagram(a, dimension)
  let db = diagram(b, dimension)
  let ea : Array[Double] = []
  let eb : Array[Double] = []
  for interval in a.intervals {
    if interval.dimension == dimension && interval.death is None {
      ea.push(interval.birth)
    }
  }
  for interval in b.intervals {
    if interval.dimension == dimension && interval.death is None {
      eb.push(interval.birth)
    }
  }
  if ea.length() != eb.length() {
    return None
  }
  ea.sort()
  eb.sort()
  let mut result = bottleneck(da, db)
  for i = 0; i < ea.length(); i = i + 1 {
    result = maximum(result, (ea[i] - eb[i]).abs())
  }
  Some(result)
}

///|
/// Sample persistent Betti counts, suitable for downstream feature extraction.
pub fn betti_curve(
  analysis : Analysis,
  dimension~ : Int,
  scales : Array[Double],
) -> Array[Int] raise TopologyError {
  let result : Array[Int] = []
  for scale in scales {
    result.push(betti(analysis, dimension, scale))
  }
  result
}
