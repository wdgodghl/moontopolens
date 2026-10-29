///|
/// Globally minimize edge count in the supplied H1 class at its birth scale.
/// Enumerate the independent 2-boundary space exactly; never silently approximate.
pub fn shortest_representative(
  analysis : Analysis,
  interval_index : Int,
  max_states? : Int = 1048576,
) -> Array[Int] raise TopologyError {
  if !analysis.representatives_computed ||
    interval_index < 0 ||
    interval_index >= analysis.intervals.length() ||
    max_states < 1 ||
    max_states > 1048576 {
    raise TopologyError(
      "shortest representative requires computed chains, a valid index and 1..1048576 states",
    )
  }
  validate_filtration(analysis.filtration)
  let interval = analysis.intervals[interval_index]
  if interval.dimension != 1 {
    raise TopologyError("exact shortest representative currently requires H1")
  }
  let cells = analysis.filtration.cells
  let mut chain = interval.representative.copy()
  chain.sort()
  let mut boundary : Array[Int] = []
  let mut last = -1
  for edge in chain {
    if edge <= last ||
      edge < 0 ||
      edge >= cells.length() ||
      cells[edge].dimension != 1 ||
      cells[edge].value > interval.birth {
      raise TopologyError("invalid birth representative")
    }
    boundary = xor_columns(boundary, cells[edge].boundary)
    last = edge
  }
  if !boundary.is_empty() {
    raise TopologyError("representative is not a cycle")
  }
  let basis : Array[Array[Int]] = []
  let owner = Array::make(cells.length(), -1)
  let mut work = 0
  for cell in cells {
    if cell.dimension != 2 || cell.value > interval.birth {
      continue
    }
    let mut column = cell.boundary.copy()
    while !column.is_empty() {
      let pivot = column[column.length() - 1]
      if owner[pivot] < 0 {
        break
      }
      work += column.length() + basis[owner[pivot]].length()
      if work > 20000000 {
        raise TopologyError("shortest cycle work budget exceeded")
      }
      column = xor_columns(column, basis[owner[pivot]])
    }
    if !column.is_empty() {
      if basis.length() >= 20 {
        raise TopologyError("exact shortest cycle boundary rank exceeds 20")
      }
      owner[column[column.length() - 1]] = basis.length()
      basis.push(column)
    }
  }
  let states = 1 << basis.length()
  if states > max_states {
    raise TopologyError("exact shortest cycle state budget exceeded")
  }
  let mut best = chain.copy()
  for state = 1; state < states; state = state + 1 {
    let mut bit = 0
    let mut value = state
    while (value & 1) == 0 {
      bit += 1
      value = value >> 1
    }
    work += chain.length() + basis[bit].length()
    if work > 20000000 {
      raise TopologyError("shortest cycle work budget exceeded")
    }
    chain = xor_columns(chain, basis[bit])
    if chain.length() < best.length() {
      best = chain.copy()
    }
  }
  best
}

///|
pub fn shortest_representative_json(
  analysis : Analysis,
  interval_index : Int,
) -> Json raise TopologyError {
  let chain = shortest_representative(analysis, interval_index)
  {
    "interval_index": interval_index,
    "scale": analysis.intervals[interval_index].birth,
    "objective": "minimum number of edges in the same GF(2) homology class at birth",
    "optimal": true,
    "representative": chain,
    "edge_count": chain.length(),
    "original_edge_count": analysis.intervals[interval_index].representative.length(),
    "note": "may be a cycle with multiple components; not minimum Euclidean length or a shortest loop across all classes",
  }
}
