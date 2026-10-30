///|
/// Exact diameter Rips with an x-coordinate sweep and sparse weighted edges.
/// No subsampling or dense n*n distance matrix. Budgets still apply.
pub fn rips_sparse(
  points : Array[Array[Double]],
  threshold~ : Double,
  max_cells~ : Int32 = 10000,
  max_dimension~ : Int32 = 2,
) -> Filtration raise TopologyError {
  let n = points.length()
  if n > 8192 ||
    !finite(threshold) ||
    threshold < 0.0 ||
    threshold > 1.0e100 ||
    (max_dimension != 2 && max_dimension != 3) {
    raise TopologyError(
      "sparse Rips requires <=8192 points, bounded nonnegative threshold and dimension 2 or 3",
    )
  }
  check_budget(n, max_cells)
  if n > 0 {
    let dimension = points[0].length()
    if dimension < 1 || dimension > 32 {
      raise TopologyError("point dimension must be 1..32")
    }
    for row in points {
      if row.length() != dimension {
        raise TopologyError("inconsistent point dimensions")
      }
      for v in row {
        if !finite(v) || v.abs() > 1.0e100 {
          raise TopologyError("invalid point coordinate")
        }
      }
    }
  }
  let raw : Array[RawCell] = []
  let weights : Array[Map[Int32, Double]] = Array::makei(n, fn(_) { Map([]) })
  let neighbors : Array[Array[Int32]] = Array::makei(n, fn(_) { [] })
  for i = 0; i < n; i = i + 1 {
    raw.push({
      key: vertex_key(i),
      dimension: 0,
      value: 0.0,
      faces: [],
      vertices: [i],
    })
  }
  let order = Array::makei(n, fn(i) { i })
  order.sort_by(fn(i, j) {
    if points[i][0] < points[j][0] {
      -1
    } else if points[i][0] > points[j][0] {
      1
    } else {
      i - j
    }
  })
  let mut work = 0
  for a = 0; a < n; a = a + 1 {
    for b = a + 1; b < n; b = b + 1 {
      let i = order[a]
      let j = order[b]
      if points[j][0] - points[i][0] > threshold {
        break
      }
      let mut d = 0.0
      for c = 0; c < points[i].length(); c = c + 1 {
        work += 1
        if work > 40000000 {
          raise TopologyError("sparse Rips coordinate work budget exceeded")
        }
        d = @math.hypot(d, points[i][c] - points[j][c])
        if d > threshold {
          break
        }
      }
      if d <= threshold {
        let u = minimum_int(i, j)
        let v = if i < j { j } else { i }
        check_budget(raw.length() + 1, max_cells)
        weights[u].set(v, d)
        neighbors[u].push(v)
        raw.push({
          key: edge_key(u, v),
          dimension: 1,
          value: d,
          faces: [vertex_key(u), vertex_key(v)],
          vertices: [u, v],
        })
      }
    }
  }
  for list in neighbors {
    list.sort()
  }
  let mut clique_work = 0
  for i = 0; i < n; i = i + 1 {
    for j in neighbors[i] {
      for k in neighbors[j] {
        clique_work += 1
        if clique_work > 2000000 {
          raise TopologyError("sparse Rips clique work budget exceeded")
        }
        let ik = match weights[i].get(k) {
          Some(v) => v
          None => continue
        }
        let d = maximum(weights[i][j], maximum(ik, weights[j][k]))
        check_budget(raw.length() + 1, max_cells)
        raw.push({
          key: triangle_key(i, j, k),
          dimension: 2,
          value: d,
          faces: [edge_key(i, j), edge_key(i, k), edge_key(j, k)],
          vertices: [i, j, k],
        })
        if max_dimension == 3 {
          for l in neighbors[k] {
            clique_work += 1
            if clique_work > 2000000 {
              raise TopologyError("sparse Rips clique work budget exceeded")
            }
            let il = match weights[i].get(l) {
              Some(v) => v
              None => continue
            }
            let jl = match weights[j].get(l) {
              Some(v) => v
              None => continue
            }
            let value = maximum(d, maximum(il, maximum(jl, weights[k][l])))
            check_budget(raw.length() + 1, max_cells)
            raw.push({
              key: tetrahedron_key(i, j, k, l),
              dimension: 3,
              value,
              faces: [
                triangle_key(i, j, k),
                triangle_key(i, j, l),
                triangle_key(i, k, l),
                triangle_key(j, k, l),
              ],
              vertices: [i, j, k, l],
            })
          }
        }
      }
    }
  }
  let f = finalize(
    raw,
    n,
    if max_dimension == 3 {
      "rips_h2"
    } else {
      "rips"
    },
    threshold,
  )
  {
    cells: f.cells,
    vertex_count: n,
    kind: f.kind,
    cutoff: threshold,
    positions: points.map(fn(p) {
      if p.length() == 1 {
        [p[0], 0.0]
      } else {
        p.copy()
      }
    }),
  }
}
